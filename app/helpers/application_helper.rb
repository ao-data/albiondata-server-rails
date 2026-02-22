module ApplicationHelper
  LANGUAGE_NAMES = {
    "EN-US" => "English (US)",
    "EN-GB" => "English (UK)",
    "EN" => "English",
    "DE" => "German",
    "FR" => "French",
    "RU" => "Russian",
    "PL" => "Polish",
    "PT-BR" => "Portuguese (Brazil)",
    "PT" => "Portuguese",
    "KO" => "Korean",
    "JA" => "Japanese",
    "ZH-CN" => "Chinese (Simplified)",
    "ZH-TW" => "Chinese (Traditional)",
    "ZH" => "Chinese",
    "ES" => "Spanish",
    "ES-MX" => "Spanish (Mexico)",
    "IT" => "Italian",
    "TR" => "Turkish",
    "TH" => "Thai",
    "VI" => "Vietnamese",
    "ID" => "Indonesian",
    "MS" => "Malay",
    "AR" => "Arabic",
    "BG" => "Bulgarian",
    "CS" => "Czech",
    "DA" => "Danish",
    "NL" => "Dutch",
    "ET" => "Estonian",
    "FI" => "Finnish",
    "EL" => "Greek",
    "HE" => "Hebrew",
    "HI" => "Hindi",
    "HU" => "Hungarian",
    "HR" => "Croatian",
    "LV" => "Latvian",
    "LT" => "Lithuanian",
    "NB" => "Norwegian (Bokmål)",
    "NN" => "Norwegian (Nynorsk)",
    "RO" => "Romanian",
    "SK" => "Slovak",
    "SL" => "Slovenian",
    "SV" => "Swedish",
    "UK" => "Ukrainian",
    "FA" => "Persian",
    "BN" => "Bengali",
    "CA" => "Catalan",
    "EU" => "Basque",
    "GL" => "Galician",
    "SR" => "Serbian",
    "MK" => "Macedonian",
    "AF" => "Afrikaans",
    "SW" => "Swahili",
    "FIL" => "Filipino",
    "X-PIRATE" => "Pirate"
  }.freeze

  def human_language_name(code)
    str = code.to_s
    LANGUAGE_NAMES[str] || format_unknown_language_code(str)
  end

  def format_unknown_language_code(code)
    return code if code.blank?

    # e.g. "EN-AU" -> "English (AU)", "XX" -> "Xx"
    parts = code.split("-", 2)
    lang = LANGUAGE_NAMES[parts[0]] || parts[0].capitalize
    parts.length == 2 ? "#{lang} (#{parts[1].upcase})" : lang
  end

  def display_name_for_item(item, preferred_lang = nil, language_keys = [])
    names = item["LocalizedNames"] || {}
    return names[preferred_lang].presence if preferred_lang.present? && names[preferred_lang].present?

    keys = language_keys.presence || names.keys.sort
    keys.each do |code|
      return names[code] if names[code].present?
    end
    names.values.first.presence || "—"
  end
end
