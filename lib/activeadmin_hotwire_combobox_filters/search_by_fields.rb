module ActiveAdminHotwireComboboxFilters
  class SearchByFields
    attr_reader :scope, :term, :fields, :klass, :table

    def initialize(scope:, term:, fields:)
      @scope = scope
      @term = term.to_s.strip
      @fields = Array(fields).map(&:to_sym)
      @klass = scope.klass
      @table = klass.arel_table
    end

    def perform
      return scope if term.blank?

      full_query = nil

      fields.each do |field|
        query = build_arel_query(field)
        next if query.nil?

        full_query = full_query ? full_query.or(query) : query
      end

      return scope.none unless full_query

      scope.where(full_query)
    end

    private

    def build_arel_query(field)
      return enum_query(field) if enum_field?(field)
      return encrypted_query(field) if encrypted_field?(field)

      case attribute_type(field)
      when :integer
        integer_query(field)
      when :datetime, :date
        datetime_query(field)
      else
        text_query(field)
      end
    end

    def text_query(field)
      table[field].matches(sanitize(term))
    end

    def integer_query(field)
      return unless integer_term?

      table[field].eq(term.to_i)
    end

    def datetime_query(field)
      clean_term = term.strip.gsub(/[\.\/\ ]/, '-')

      if clean_term.match?(/\A\d{2,4}-\d{2}-\d{2,4}\z/)
        parsed_date = try_parse_smart_date(clean_term)

        return table[field].eq(parsed_date) if parsed_date
      end

      if clean_term.match?(/\A\d{2,4}\z/) || clean_term.match?(/\A\d{2,4}-\d{2,4}\z/)
        sanitized_term = sanitize(clean_term)
        to_char_ymd = Arel::Nodes::NamedFunction.new('TO_CHAR', [table[field], Arel::Nodes.build_quoted('YYYY-MM-DD')])
        to_char_dmy = Arel::Nodes::NamedFunction.new('TO_CHAR', [table[field], Arel::Nodes.build_quoted('DD-MM-YYYY')])

        return to_char_ymd.matches(sanitized_term).or(to_char_dmy.matches(sanitized_term))
      end

      nil
    end

    def enum_query(field)
      enum_map = klass.defined_enums[field.to_s]
      return unless enum_map

      matches = []
      translations = i18n_enum_translations(field)
      lower_case_term = term.downcase

      if translations.is_a?(Hash)
        translations.each do |key, value|
          matches << enum_map[key] if value.to_s.downcase.include?(lower_case_term)
        end
      end

      return if matches.empty?

      table[field].in(matches)
    end

    def encrypted_query(field)
      table[field].eq(term)
    end

    def try_parse_smart_date(str)
      current_date = Date.current
      formats = %w[%d-%m-%y %d-%m-%Y %Y-%m-%d %y-%m-%d]
      fallback_parsed_date = nil

      formats.each do |format|
        date = Date.strptime(str, format)
        fallback_parsed_date ||= date

        return date if date <= current_date + 1.day
      rescue ArgumentError
        next
      end

      fallback_parsed_date
    end

    def attribute_type(field)
      klass.attribute_types[field.to_s]&.type
    end

    def integer_term?
      term.match?(/\A\d+\z/)
    end

    def enum_field?(field)
      klass.defined_enums.key?(field.to_s)
    end

    def encrypted_field?(field)
      klass.encrypted_attributes&.include?(field)
    end

    def i18n_enum_translations(field)
      I18n.t("activerecord.attributes.#{klass.model_name.i18n_key}/#{field}")
    end

    def sanitize(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
    end
  end
end
