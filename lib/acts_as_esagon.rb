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
    attr_reader :klass, :type, :properties, :attributes
    
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
      @klass = klass
      @type = type
      @properties = options
      @attributes = {}
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
    # - :values => #String (valori ammessi, secondo il formato: value_1|label_1#value_2|label_2#...#value_n|label_n)
    # - :values_sql => #String (espressione SQL dei valori ammessi come lookup, secondo il formato: select <value>, <label> from <lookup_table>..)
    # - :repository => #String (percorso della cartella dei contenuti, relativo alla erpository dell'applicazione)
    # - :width => #Fixnum (larghezza standard)
    # - :height => #Fixnum (altezza standard)
    # - :searchable => *true* o false (indica se includere il campo nelle tendine di ricerca, default false per i campi con :repository non nulla)
    def attribute(options = {})
      @attributes[options.delete :name] = options
    end
    
    def method_missing(name, *args, &block)
      @attributes[name.to_s] = args[0] if !args.nil? && args.size > 0 && (args[0].is_a? Hash)
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
      !@binding.nil? && @binding.type == type
    end
    
    def to_xml
      builder = Builder::XmlMarkup.new :indent => 2, :margin => 2
      case @binding.type
        when :entity then build_entity(builder)
        when :relation then build_relation(builder)
      end
    end
    
    private
    
    NON_EXPORTABLE_ATTRIBUTES = [%r{^id$}, %r{_lm$}i, %r{_ol$}i, %r{_ow$}i, %r{^created_at$}, %r{^updated_at$}]
    
    def build_entity(builder)
      builder.entity build_options(@binding.properties, :personalized => false, :preview => false, :name => self.name.underscore, :type => :primary) do |e|
        e.ord @binding.properties[:order] if !@binding.properties[:order].blank?
        e.label @binding.properties[:label] || self.name.underscore
        e.table self.table_name
        e.schema @binding.properties[:schema] if !@binding.properties[:schema].blank?
        e.catalog @binding.properties[:catalog] if !@binding.properties[:catalog].blank?
        e.partition @binding.properties[:partition] if !@binding.properties[:partition].blank?
        e.idName 'id'
        e.idType 'integer'
        e.idColumn self.primary_key
        e.idGenerator @binding.properties[:id_generator] if !@binding.properties[:id_generator].blank?
        e.customMapping @binding.properties[:custom_mapping] if !@binding.properties[:custom_mapping].blank?
        e.notify true if @binding.properties[:notify] == true
        e.editRole @binding.properties[:edit_role] if !@binding.properties[:edit_role].blank?
        e.publishRole @binding.properties[:publish_role] if !@binding.properties[:publish_role].blank?
        e.title @binding.properties[:title] || 'id'
        e.links @binding.properties[:links] if !@binding.properties[:links].blank?
        e.command @binding.properties[:command] if !@binding.properties[:command].blank?
        e.category 'T'
        columns_hash.each { |n, c| build_attribute(e, n, c) }
      end
    end
    
    def build_relation(builder)
      builder.relation build_options(@binding.properties, :name => self.name.underscore) do |r|
        r.label @binding.properties[:label] || self.name.underscore
        r.table self.table_name
        r.schema @binding.properties[:schema] if !@binding.properties[:schema].blank?
        r.catalog @binding.properties[:catalog] if !@binding.properties[:catalog].blank?
        r.partition @binding.properties[:partition] if !@binding.properties[:partition].blank?
        r.idName 'id'
        r.idType 'integer'
        r.idColumn self.primary_key
        r.idGenerator @binding.properties[:id_generator] if !@binding.properties[:id_generator].blank?
        r.customMapping @binding.properties[:custom_mapping] if !@binding.properties[:custom_mapping].blank?
        r.notify true if @binding.properties[:notify] == true
        @binding.klass.reflections.each { |k, v, m| r.partecipant k.to_s if v.macro == :belongs_to }
        columns_hash.each { |n, c| build_attribute(r, n, c) }
      end
    end
    
    def build_attribute(b, n, c)
      attribute = @binding.attributes[n] || {}
      if exportable?(n, attribute) then
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
          a.values attribute[:values] if !attribute[:values].blank?
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
      end
    end
    
    def exportable?(n, attribute)
      name = attribute[:name] || n
      attribute[:export] != false && !NON_EXPORTABLE_ATTRIBUTES.inject(false) { |c, expr| c |= expr.match(name) } &&
      (@binding.type == :entity || !@binding.klass.reflections.find { |k, v| v.macro == :belongs_to })
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
      attribute = @binding.attributes[n] || {}
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