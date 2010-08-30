class <%= migration_name %> < ActiveRecord::Migration
  
<% list_of_models.each do |model| -%>
  class <%= model.classify %> < ActiveRecord::Base
  end
<% end -%>

  def self.up
<% list_of_models.each do |model| -%>
    change_table(:<%= model.classify.constantize.table_name %>) do |t|
       t.datetime :<%= model %>_LM
       t.string :<%= model %>_OW
       t.string :<%= model %>_OL
    end
<% end -%>
  end
  
  def self.down
<% list_of_models.each do |model| -%>
<% ['LM', 'OW', 'OL'].each do |e| -%>
    remove_column :<%= model.classify.constantize.table_name %>, :<%= "#{model}_#{e}" %>
<% end -%><% end -%>
  end
end
