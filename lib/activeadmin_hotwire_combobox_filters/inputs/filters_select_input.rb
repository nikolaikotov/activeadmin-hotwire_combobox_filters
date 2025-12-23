ActiveAdmin::Inputs::Filters::SelectInput.class_eval do
  include ActiveAdminHotwireComboboxFilters::InputsCommon

  def select_html # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return super if @options[:collection] || !reflection

    current_value = object.public_send(input_name)

    items = []
    if current_value.present?
      value_record = template.active_admin_authorization.scope_collection(reflection.klass).find_by(id: current_value)
      items = HotwireCombobox::Listbox::Item.collection_for(
        template, [value_record], render_in: {}, include_blank: nil, display: :to_combobox_display
      )
    end

    path = build_search_url(@options)

    builder.combobox(input_name, path, value: current_value, options: items)
  end

end
