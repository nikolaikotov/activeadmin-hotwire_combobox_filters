module ActiveAdmin
  module Inputs
    class HotwireComboboxInput < Formtastic::Inputs::SelectInput
      include ActiveAdminHotwireComboboxFilters::InputsCommon

      def select_html
        path_or_collection = build_search_url(options) || collection

        res = +''.html_safe

        unless template.instance_variable_defined?(:@aa_hw_combobox_styles_rendered)
          res << template.render(partial: "activeadmin_hotwire_combobox_filters/combobox_styles")
          template.instance_variable_set(:@aa_hw_combobox_styles_rendered, true)
        end

        res << builder.combobox(input_name, path_or_collection)
      end
    end
  end
end
