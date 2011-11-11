class ActsAsEsagonGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :name, :type => :string, :optional => true, :desc => 'Model name'
  argument :only, :type => :array, :optional => true, :desc => 'List of models to include'
  
  class_option :configuration, :type => :boolean, :default => false,:desc => 'Write base configuration'
  class_option :xml, :type => :boolean, :default => false, :desc => "Indicates when to generate the Esagon XML file descriptor"
  class_option :migration, :type => :boolean, :default => false, :desc => "Indicates when to generate the database migration file"


  def write_base_configuration
    if options.configuration? 
      models=Dir.glob(File.join(Rails.root,"app","models","*.rb"))
      models.each do |model_path|
        model_name=model_path.split("/").last.split(".").first
        if (only.blank? || only.include?(model_name))
          generate_fields_for_model! model_name
        end
      end
    end
  end
  

  def generate_xml
    template "esagon.xml.erb", "tmp/esagon.xml" if options.xml?
  end

  def generate_migration
    if options.migration? then
      if list_of_models.size > 0
        template "migration.rb", "db/migrate/#{Time.now.strftime('%Y%m%d%H%M%S')}_#{migration_name.underscore}.rb"
      else
        puts "No need to migrate: #{list_of_models(nil, true).map { |m| m.camelize }.join(', ')}"
      end
    end
  end


  private

  def generate_fields_for_model! model_name
    klass=model_name.camelcase.constantize
    columns=klass.column_names
    columns=columns.keep_if {|c|!(["id","updated_at","created_at"].include? c)}
    col_with_options={}
    columns.each do |c|
    col_with_options[c]=get_options_for model_name,c
    end
       
    template=ERB.new <<-EOF
    acts_as_esagon_entity :label => #{model_name.camelcase}, :title => 'id' do |e|
    <%col_with_options.each do |c,opt|%>
      e.<%=c%> '<%=c.camelcase%>'<%if !opt.blank?%>, <%= opt.to_s %> <%end%>
      <%end%>
    end
EOF
    add_code model_name, template.result(binding)
  end

  def get_options_for model_name,column
    aux=nil
    if column.match(/content_type/) 
      aux={:export=>false}
    elsif column.match(/file_name/)
      
      begin
      if model_name.classify.constantize.attachment_definitions.include? column.gsub("_file_name","").to_sym
        aux= {:repositiory=>model_name.classify.constantize.attachment_definitions[column.gsub("_file_name","").to_sym][:url].split("/")[0..-2].join("/")}
      end
      rescue Exception=>e
      puts "WARNING: check #{model_name} paperclip url ."
      end
    elsif column.match(/file_size/)
      aux={:export=>false}
    end
    aux
  end

  def add_code(model_name,str)
    model_path=File.join(Rails.root,"app","models","#{model_name}.rb")
    input_string=File.read(model_path)
    output_string=""
    input_string.each_line do |l|
      if l.match("ActiveRecord::Base")
        output_string+= l+"\n"+str+"\n"
      else
        output_string+=l 
      end

    end
    File.open(model_path, 'w') {|f| f.write(output_string) }
  end


  def list_of_models(type = nil, force = false)
    all_models = Dir.glob( File.join( Rails.root, 'app', 'models', '*.rb') ).map { |path| path[/.+\/(.+).rb/,1] }
    all_models = all_models.select { |m| m.camelize == name } unless name.blank?
    ar_models = all_models.select { |m| m.camelize.constantize < ActiveRecord::Base }
    ar_models = ar_models.select { |model| model.camelize.constantize.methods.select { |m| m == :has_esagon_bindings? }.length > 0 }
    ar_models = ar_models.select { |model| model.camelize.constantize.has_esagon_bindings?(type) } unless type.nil?
    ar_models = ar_models.select { |model| !model.camelize.constantize.columns_hash.has_key?("#{model.camelize.constantize.esagon_binding_properties[:name]}_LM") rescue false } if options.migration? && !force
    ar_models
  end

  def migration_name
    "AddEsagonBindingsTo#{list_of_models.map { |m| m.camelize }.join('And')}".slice(0, 127)
  end
end
