class ComboboxSearcher
  attr_reader :scope, :term, :fields, :klass

  def initialize(scope:, term:, fields:)
    @scope = scope
    @term = term.to_s.strip
    @fields = Array(fields).map(&:to_sym)
    @klass = scope.klass
  end

  def perform
    return scope.none if term.blank?

    queries = build_queries.compact
    return scope.none if queries.empty?

    queries.reduce(scope.none) do |relation, query|
      relation.or(query)
    end
  end

  private

  def integer_term?
    term.match?(/\A\d+\z/)
  end

  def build_queries
    fields.map do |field|
      build_query_for(field)
    end
  end

  def build_query_for(field)
    return enum_query(field) if enum_field?(field)
    return encrypted_query(field) if encrypted_field?(field)

    type = attribute_type(field)

    case type
    when :integer
      integer_query(field)
    when :datetime, :date, :time, :timestamp
      datetime_query(field)
    else
      text_query(field)
    end
  end

  def text_query(field)
    scope.where("#{quoted(field)} ILIKE :term", term: sanitize(term))
  end

  def integer_query(field)
    return unless integer_term?

    scope.where(field => term.to_i)
  end

  def datetime_query(field)
    q_column = quoted(field)
    normalized_term = term.gsub(/[\.\/\ ]/, '-')
    sql_string = "TO_CHAR(#{q_column}, 'YYYY-MM-DD') ILIKE :q OR TO_CHAR(#{q_column}, 'DD-MM-YYYY') ILIKE :q"

    scope.where(sql_string, q: sanitize(normalized_term))
  end

  def enum_query(field)
    enum_map = klass.defined_enums[field.to_s]
    return unless enum_map

    matches = []
    translations = i18n_enum_translations(field)

    if translations.is_a?(Hash)
      translations.each do |key, value|
        matches << enum_map[key] if value.to_s.downcase.include?(term.downcase)
      end
    end

    matches.compact!
    return if matches.empty?

    scope.where(field => matches.uniq)
  end

  def encrypted_query(field)
    scope.where(field => term)
  end

  def attribute_type(field)
    klass.attribute_types[field.to_s]&.type
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

  def quoted(field)
    scope.connection.quote_column_name(field)
  end

  def sanitize(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end
end
