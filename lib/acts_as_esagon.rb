# ActsAsEsagon
module ActsAsEsagon
  class << self
    attr_accessor :name, :logo, :repository
    attr_accessor :dialect, :hbm2ddl_auto
    attr_accessor :connection_driver_class, :connection_url, :connection_username, :connection_password, :connection_pool_size, :connection_properties
  end
  
  def self.included(base)
    base.send :extend, ClassMethods
  end

  class Binding
    instance_methods.each { |m| undef_method m unless m =~ /^__|object_id|nil\?/}
    attr_reader :__klass__, :__type__, :__properties__, :__attributes__
    
    # La mappa delle proprietà dell'entità/relazione prevede le seguenti opzioni:
    # - :personalized => true o *false* (entità presonalizzata o meno)
    # - :preview => true o *false* (indica se la colonna :title è da considerare come immagine o eno)
    # - :type => *:primary* o :secondary (tipo di entità)
    # - :order => #Fixnum (ordine con cui mostrare l'attributo nella lista)
    # - :label => #String (etichetta)
    # - :schema => #String (schema database, se previsto)
    # - :catalog => #String (catalogo database, se previsto)
    # - :partition => #String (partizione database, se prevista)
    # - :notify => true o *false* (abilitazione della notifica)
    # - :edit_role => #Stirng (ruolo di edit per l'entità/relazione)
    # - :publish_role => #Stirng (ruolo di pubblicazione per l'entità/relazione)
    # - :title => #String (espressione SQL per la costruzione della colonna del titolo)
    # - :links => #String (collegamenti esterni)
    # - :command => #String (comando di apertura)
    def initialize(klass, type, options = {})
      @__klass__ = klass
      @__type__ = type
      @__properties__ = options
      @__attributes__ = {}
      yield(self) if block_given?
    end

    # La mappa delle proprietà dell'attributo prevdere le seguenti opzioni:
    # - :nullable => *true* o false (indica se il campo può essere nullo)
    # - :client_type => #String (indica il tipo di controllo da utilizzare per la presentazione all'utente)
    # => 'textfield' (default per campi :string)
    # => 'tokenbox' (lista di valori stringa separati da ',' che funziona con lo stesso principio di una combobox a selezione multipla)
    # => 'combobox' (lista a selezione singola)
    # => 'listbox' (lista a selezione multipla)
    # => 'textarea' (default per campi :text)
    # => 'sliderfield' (slider per campi :integer)
    # => 'datefield' (default per i campi :date)
    # => 'timefield' (default per i campi :time)
    # => 'datetimefield'
    # => 'checkbox' (default per i campi :boolean)
    # => 'file' (default per i campi in cui è valorizzato l'attributo :repository)
    # - :label => #String (etichetta)
    # - :update => *true* o false (indica se includere il campo nelle istruzioni di update)
    # - :insert => *true* o false (indica se includere il campo nelle istruzioni di insert)
    # - :formula => #String (espressione SQL se il campo è calcolato)
    # - :unique => true o *false* (indica se includere il campo è univoco)
    # - :values => #Hash (valori ammessi, convertiti secondo il formato: value_1|label_1#value_2|label_2#...#value_n|label_n)
    # - :values_sql => #String (espressione SQL dei valori ammessi come lookup, secondo il formato: select <value>, <label> from <lookup_table>..)
    # - :repository => #String (percorso della cartella dei contenuti, relativo alla erpository dell'applicazione)
    # - :width => #Fixnum (larghezza standard)
    # - :height => #Fixnum (altezza standard)
    # - :searchable => *true* o false (indica se includere il campo nelle tendine di ricerca, default false per i campi con :repository non nulla)
    def attribute(options = {})
      add_attribute options.delete(:name), options if options.is_a? Hash
    end
    
    def method_missing(name, *args, &block)
      unless args.nil?
        if args[0].is_a?(Hash)
          label, options = nil, args[0]
        else
          label, options = args[0].to_s, args[1]
        end
        options ||= {}
        if options.is_a? Hash
          options[:label] = label unless label.blank?
          add_attribute(name.to_s, options)
        end
      end
    end
    
    private
    
    def add_attribute(n, v)
      if @__klass__.columns_hash.each_key.include?(n)
        @__attributes__[n] = v
        @__klass__.columns_hash.each_key do |k|
          if k.match("^#{n}_([a-z]{2})$") then
            @__attributes__[k] ||= v.clone
            @__attributes__[k].each { |ak, av| @__attributes__[k][ak] = "#{av} (#{$1})" }
          end
        end
      else
        puts "Warning: trying to describe non-existing #{@__klass__}##{n}!"
      end
    end
  end

  module ClassMethods
    # any method placed here will apply to classes, like Hickwall
    def acts_as_esagon_entity(options = {}, &block)
      send :include, EntityInstanceMethods
      send :extend, SingletonMethods

      @binding = Binding.new(self, :entity, options, &block)
    end

    def acts_as_esagon_relation(options = {}, &block)
      send :include, RelationInstanceMethods
      send :extend, SingletonMethods
      
      @binding = Binding.new(self, :relation, options, &block)
    end    
  end
  
  module SingletonMethods
    def has_esagon_bindings?(type)
      !@binding.nil? && @binding.__type__ == type
    end
    
    def to_xml
      columns_hash.each_key do |k|
        puts "Warning: #{self}##{k} was not specified and will take default values, did u miss something?" if exportable?(k) && !@binding.__attributes__.keys.include?(k)
      end
      builder = Builder::XmlMarkup.new :indent => 2, :margin => 2
      case @binding.__type__
        when :entity then build_entity(builder)
        when :relation then build_relation(builder)
      end
    end
    
    private
    
    NON_EXPORTABLE_ATTRIBUTES = %r{^id|.+_lm|.+_ol|.+_ow|created_at|updated_at$}
    
    def build_entity(builder)
      builder.entity build_options(@binding.__properties__, :personalized => false, :preview => false, :name => self.name.underscore, :type => :primary) do |e|
        e.ord @binding.__properties__[:order] if !@binding.__properties__[:order].blank?
        e.label @binding.__properties__[:label] || self.name.underscore
        e.table self.table_name
        e.schema @binding.__properties__[:schema] if !@binding.__properties__[:schema].blank?
        e.catalog @binding.__properties__[:catalog] if !@binding.__properties__[:catalog].blank?
        e.partition @binding.__properties__[:partition] if !@binding.__properties__[:partition].blank?
        e.idName 'id'
        e.idType 'integer'
        e.idColumn self.primary_key
        e.idGenerator @binding.__properties__[:id_generator] if !@binding.__properties__[:id_generator].blank?
        e.customMapping @binding.__properties__[:custom_mapping] if !@binding.__properties__[:custom_mapping].blank?
        e.notify true if @binding.__properties__[:notify] == true
        e.editRole @binding.__properties__[:edit_role] if !@binding.__properties__[:edit_role].blank?
        e.publishRole @binding.__properties__[:publish_role] if !@binding.__properties__[:publish_role].blank?
        e.title @binding.__properties__[:title] || 'id'
        e.links @binding.__properties__[:links] if !@binding.__properties__[:links].blank?
        e.command @binding.__properties__[:command] if !@binding.__properties__[:command].blank?
        e.category 'T'
        columns_hash.each { |n, c| build_attribute(e, n, c) }
      end
    end
    
    def build_relation(builder)
      builder.relation build_options(@binding.__properties__, :name => self.name.underscore) do |r|
        r.label @binding.__properties__[:label] || self.name.underscore
        r.table self.table_name
        r.schema @binding.__properties__[:schema] if !@binding.__properties__[:schema].blank?
        r.catalog @binding.__properties__[:catalog] if !@binding.__properties__[:catalog].blank?
        r.partition @binding.__properties__[:partition] if !@binding.__properties__[:partition].blank?
        r.idName 'id'
        r.idType 'integer'
        r.idColumn self.primary_key
        r.idGenerator @binding.__properties__[:id_generator] if !@binding.__properties__[:id_generator].blank?
        r.customMapping @binding.__properties__[:custom_mapping] if !@binding.__properties__[:custom_mapping].blank?
        r.notify true if @binding.__properties__[:notify] == true
        @binding.__klass__.reflections.each { |k, v, m| r.partecipant k.to_s if v.macro == :belongs_to }
        columns_hash.each { |n, c| build_attribute(r, n, c) }
      end
    end
    
    def build_attribute(b, n, c)
      attribute = @binding.__attributes__[n] || {}
      if exportable?(n, attribute)
        b.attribute build_options(attribute, :name => n, :nullable => c.null, :client_type => default_client_type(n, c)) do |a|
          a.label attribute[:label] || n.humanize
          a.format attribute[:format] if !attribute[:format].blank?
          a.column c.name
          a.type attribute[:type] || c.type.to_s
          a.send :'column-type', c.sql_type.to_s
          a.update false if attribute[:update] == false
          a.insert false if attribute[:insert] == false
          a.formula attribute[:formula] if !attribute[:formula].blank?
          a.unique true if attribute[:unique] == true
          a.values attribute[:values].flat_map { |k, v| "#{k}|#{v}" }.join('#') if !attribute[:values].blank?
          a.send :'values-sql', attribute[:values_sql] if !attribute[:values_sql].blank?
          a.generated attribute[:generated] if !attribute[:generated].blank?
          a.length c.limit if !c.limit.blank?
          a.precision c.precision if !c.precision.blank?
          a.scale c.scale if !c.scale.blank?
          a.repository attribute[:repository] if !attribute[:repository].blank?
          a.width attribute[:width] if !attribute[:width].blank?
          a.height attribute[:height] if !attribute[:height].blank?
          if !attribute[:searchable].nil? then
            a.searchable attribute[:searchable] == true
          else
            a.searchable attribute[:repository].blank?
          end
        end
      else
        puts "Info: skipping non-exportable #{self}##{n}"
      end
    end
    
    def exportable?(n, attribute = {})
      name = attribute[:name] || n
      attribute[:export] != false && NON_EXPORTABLE_ATTRIBUTES !~ n &&
      (@binding.__type__ == :entity || !@binding.__klass__.reflections.find { |k, v| v.macro == :belongs_to })
    end
    
    def build_options(source, options = {})
      result = {}
      options.each do |k, v|
        t = case k
          when :client_type then :'client-type'
          else
            k
        end
        result[t] = source[k] || v
      end
      result
    end
    
    def default_client_type(n, c)
      attribute = @binding.__attributes__[n] || {}
      if !attribute[:repository].blank? then
        'file'
      else
        case c.type
          when :string, :integer then !attribute[:values].blank? || !attribute[:values_sql].blank? ? 'combobox' : 'textfield'
          when :text then 'textarea'
          when :date then 'datefield'
          when :time then 'timefield'
          when :datetime, :timestamp then 'datetimefield'
          when :boolean then 'checkbox'
          else
            nil
        end
      end
    end

  end

  module EntityInstanceMethods
    # any method placed here will apply to instaces, like @hickwall
  end

  module RelationInstanceMethods
    # any method placed here will apply to instaces, like @hickwall
  end
end