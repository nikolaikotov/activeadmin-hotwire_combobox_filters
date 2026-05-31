class ActiveAdminHotwireComboboxFilters::MatchDatePartially
  class << self
    # Checks whether the given string matches a full date or a partial date
    # according to the current locale's `date.formats.default` format.
    #
    # The date format is taken from I18n translations and may be, for example:
    # `%m/%d/%Y`, `%Y-%m-%d`, `%d.%m.%Y`, etc.
    #
    # Returns an array containing:
    # - a boolean indicating whether the string matches a full or partial date
    #   in the configured format
    # - a Date object if all date parts are present and form a valid date;
    #   otherwise nil
    #
    # Examples (assuming `date.formats.default` is `%Y-%m-%d`):
    #
    #   perform("2026-05-30") # => [true, <Date 2026-05-30>]
    #   perform("2026-05")    # => [true, nil]
    #   perform("05-30")      # => [true, nil]
    #   perform("2026-05 aa") # => [false]
    def perform(str)
      local_date_parts_regexps.size.times do |start_part_i|
        matched_parts_count = try_match(str, start_part_i)
        next if matched_parts_count == 0
        full_date_match = (Date.strptime(str, format) if matched_parts_count == local_date_parts_regexps.size)
        return [true, full_date_match]
      end
      [false]
    end

    private

    def local_date_parts_regexps
      @local_date_parts_regexps ||= begin
        format.scan(/%\w+|[^%]+/).map do |matched_s|
          case matched_s
          when "%d" then /0[1-9]|[12][0-9]|3[01]/
          when "%m" then /0[1-9]|1[0-2]/
          when "%Y" then /\d{4}/
          when "%y" then /\d{2}/
          else Regexp.new(Regexp.escape(matched_s))
          end
        end
      end
    end

    def try_match(str, start_part_i)
      cur_pos = 0
      (start_part_i...local_date_parts_regexps.size).each do |part_i|
        regexp = local_date_parts_regexps[part_i]
        m = str.match(regexp, cur_pos)
        return 0 if !m || m.begin(0) != cur_pos
        cur_pos += m[0].size
        return part_i - start_part_i + 1 if cur_pos == str.size
      end
      0
    end

    def format
      I18n.t('date.formats.default')
    end

  end
end
