# frozen_string_literal: true

# Reads the text back out of a rendered Prawn document, for the specs that
# assert on what a PDF says rather than on how it was built.
module PdfText
  # Prawn writes each text run as a hex-encoded string inside a `[...] TJ`
  # operator, split into several chunks when kerning applies. Joining the
  # chunks of one operator gives back the cell's text.
  def texts_in(pdf)
    pdf.render.scan(/\[(.*?)\]\s*TJ/m).flatten.map { |run| pdf_text_of(run) }
  end

  # Each text run is positioned by a `BT ... Td ... TJ ... ET` block; the
  # second number of the Td is its baseline down the page.
  def text_positions_in(pdf)
    pdf.render.scan(/BT(.*?)ET/m).flatten.filter_map do |block|
      baseline = block[/([\d.]+)\s+([\d.-]+)\s+Td/, 2]
      text = pdf_text_of(block)
      [baseline.to_f.round, text] if baseline && !text.empty?
    end.sort
  end

  # Windows-1252 is the only encoding Prawn's built-in fonts speak, so an em
  # dash arrives as one byte and has to be decoded before it can be compared
  # with the UTF-8 string a spec writes.
  private def pdf_text_of(chunk)
    chunk.scan(/<([0-9A-Fa-f]+)>/).flatten.map { |hex| [hex].pack("H*") }.join
      .force_encoding(Encoding::WINDOWS_1252)
      .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end
end

RSpec.configure do |config|
  config.include PdfText
end
