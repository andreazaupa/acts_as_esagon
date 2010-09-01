class ActsAsEsagonGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  argument :name, :type => :string, :optional => true, :desc => 'Model name'
  class_option :xml, :type => :boolean, :default => false, :desc => "Indicates when to generates the Esagon XML file descriptor"
  class_option :migration, :type => :boolean, :default => false, :desc => "Indicates when to generates the database migration file"
  
  def generate_xml
    template "esagon.xml.erb", "tmp/esagon.xml" if options.xml?
  end
  
  def generate_migration
    if options.migration? then
      if list_of_models.size > 0
        template "migration.rb", "db/migrate/#{Time.now.strftime('%Y%m%d%H%M%S')}_#{migration_name.underscore}.rb"
      else
        puts "No need to migrate: #{list_of_models(nil, true).map { |m| m.classify }.join(',')}"
      end
    end
  end
  
  private
  
  def list_of_models(type = nil, force = false)
    all_models = Dir.glob( File.join( Rails.root, 'app', 'models', '*.rb') ).map { |path| path[/.+\/(.+).rb/,1] }
    all_models = all_models.select { |m| m.classify == name } unless name.blank?
    ar_models = all_models.select { |m| m.classify.constantize < ActiveRecord::Base }
    ar_models = ar_models.select { |model| model.classify.constantize.methods.select { |m| m == :has_esagon_bindings? }.length > 0 }
    ar_models = ar_models.select { |model| model.classify.constantize.has_esagon_bindings?(type) } unless type.nil?
    ar_models = ar_models.select { |model| !model.classify.constantize.columns_hash.has_key?("#{model}_LM") } if options.migration? && !force
    ar_models
  end
  
  def migration_name
    "AddEsagonBindingsTo#{list_of_models.map { |m| m.classify }.join('And')}".slice(0, 127)
  end
end
