module ActiveAdminHotwireComboboxFilters::InputsCommon
  private

  def build_search_url(options)
    params = prepare_search_fields_params(@options[:search_fields])

    if (url = options[:url])
      url.respond_to?(:call) ? url.call(params) : "#{url}?#{params.to_param}"
    elsif reflection
      template.public_send(:"combobox_search_admin_#{reflection.klass.name.tableize}_path", params)
    end
  end

  def prepare_search_fields_params(search_fields)
    search_fields ||= reflection&.klass&.try(:hw_search_fields)
    search_fields = search_fields&.then { |fields| Array(fields) } || [default_search_field]

    { search_fields: }
  end

  def default_search_field
    reflection_class = reflection.klass
    method_names = template.active_admin_application.display_name_methods
    column_names = reflection_class.column_names.map(&:to_sym)
    method = method_names.find { |name| name.in?(column_names) }

    unless method
      raise NoMethodError, <<~MSG.squish
      No display method found for #{reflection_class.name}.
      Methods searched: #{method_names.join(', ')}
    MSG
    end

    method
  end

end