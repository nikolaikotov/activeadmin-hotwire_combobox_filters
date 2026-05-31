class ActiveAdminHotwireComboboxFilters::SearchByFields
  attr_reader :scope, :term, :fields, :klass, :table

  def initialize(scope:, term:, fields:)
    @scope = scope
    @term = term.to_s.strip
    @fields = Array(fields).map(&:to_sym)
    @klass = scope.klass
    @table = klass.arel_table
  end

  def perform
    query = fields.filter_map { |field| build_field_query(field) }.reduce(:or)
    query ? scope.where(query) : scope.none
  end

  private

  def build_field_query(field)
    return enum_query(field) if enum_field?(field)
    return encrypted_query(field) if encrypted_field?(field)

    field_type = attribute_type(field)

    case field_type
    when :integer then integer_query(field)
    when :date then datetime_query(field)
    when :string, :text then text_query(field)
    else raise NotImplementedError, "No search logic implemented for type #{field_type} (#{klass}.#{field})"
    end
  end

  def text_query(field)
    table[field].matches(expression_contains(term))
  end

  def integer_query(field)
    return unless integer_term?

    table[field].eq(term.to_i)
  end

  def datetime_query(field)
    matched, matched_full_date = ActiveAdminHotwireComboboxFilters::MatchDatePartially.perform(term)
    return unless matched
    return table[field].eq(matched_full_date) if matched_full_date

    to_char = Arel::Nodes::NamedFunction.new('TO_CHAR', [table[field], Arel::Nodes.build_quoted(db_date_format)])
    to_char.matches(expression_contains(term))
  end

  def enum_query(field)
    translations = i18n_enum_translations(field)
    unless translations.is_a?(Hash)
      raise StandardError,
        "No translations for enum field: activerecord.attributes.#{klass.model_name.i18n_key}/#{field}"
    end

    enum_map = klass.defined_enums.fetch(field.to_s)
    lower_case_term = term.downcase
    matches = []

    translations.each do |key, value|
      matches << enum_map[key] if value.to_s.downcase.include?(lower_case_term)
    end

    table[field].in(matches) if matches.any?
  end

  def encrypted_query(field)
    table[field].eq(term)
  end

  def attribute_type(field)
    klass.type_for_attribute(field)&.type
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

  def expression_contains(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end

  delegate :db_date_format, to: :class

  class << self
    def db_date_format
      @db_date_format ||=
        I18n.t('date.formats.default').scan(/%\w+|[^%]+/).map do |matched_s|
          case matched_s
          when "%d" then 'DD'
          when "%m" then 'MM'
          when "%Y" then 'YYYY'
          when "%y" then 'YY'
          else matched_s
          end
        end.join
    end
  end

end
