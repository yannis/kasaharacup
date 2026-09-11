# frozen_string_literal: true

# Picks the best locale the site offers out of an `Accept-Language` header, or
# nil when the visitor asks for nothing it has.
#
# Ported from the `ErrorPages::Locale` deleted in #1268, which is the
# implementation issue #1267 points at as correct.
class AcceptLanguage
  # RFC 9110: a tag is `language["-"script]["-"region]...`, so only the primary
  # subtag names the language. Anchoring there keeps "fry" (West Frisian) from
  # matching "fr", and keeps the region of a three-letter tag like "gsw-FR"
  # from being read as one.
  PRIMARY_SUBTAG = /\A\s*([a-z]{2})(?=[-;\s]|\z)/

  # RFC 9110: `qvalue = ( "0" [ "." 0*3DIGIT ] ) / ( "1" [ "." 0*3("0") ] )`.
  # The digits after the point are optional, so "1." is a well-formed 1.0.
  QVALUE = /\A(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)\z/

  def self.best_locale(header) = new(header).best_locale

  def initialize(header)
    @header = header.to_s
  end

  def best_locale
    accepted_tags.lazy.filter_map { |tag| available(tag[PRIMARY_SUBTAG, 1]) }.first
  end

  # The tags the visitor will actually accept, best first. Language tags are
  # case-insensitive, and header order is not preference order — q-values are.
  # `sort_by` is not stable in Ruby, so the index breaks ties and keeps
  # "en,fr" reading left to right.
  private def accepted_tags
    @header.downcase
      .split(",")
      .each_with_index
      .map { |tag, index| [tag, index, quality(tag)] }
      .select { |_tag, _index, quality| quality&.positive? }
      .sort_by { |_tag, index, quality| [-quality, index] }
      .map(&:first)
  end

  # RFC 9110: a weight is 0-1 with at most three decimals, and `q=0` means
  # "not acceptable" rather than "least preferred". A malformed weight is not
  # a preference either, so both are dropped rather than guessed at — nil here
  # removes the tag from consideration.
  #
  # The weight is stripped because RFC 9110 list syntax is
  # `element *( OWS "," OWS element )`, so "fr;q=0.2 ,en" is legal and the
  # space belongs to the list, not to the weight.
  private def quality(tag)
    weight = tag[/;\s*q=([^;]*)/, 1]&.strip
    return 1.0 if weight.nil?

    weight.match?(QVALUE) ? weight.to_f : nil
  end

  private def available(code)
    code.to_s.to_sym.presence_in(I18n.available_locales)
  end
end
