// lib/utilities/country_data_helper.dart
// Provides country-specific data for Trip Essentials
// All data is FREE - no API needed, static data

class CountryDataHelper {
  /// Get all essential data for a country
  static CountryEssentials getCountryEssentials(String country) {
    final countryLower = country.toLowerCase().trim();

    // Try to find exact match first
    for (final entry in _countryData.entries) {
      if (entry.key.toLowerCase() == countryLower) {
        return entry.value;
      }
    }

    // Try partial match
    for (final entry in _countryData.entries) {
      if (countryLower.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(countryLower)) {
        return entry.value;
      }
    }

    // Return default/generic
    return _defaultEssentials;
  }

  /// Get currency code for a country
  static String getCurrencyCode(String country) {
    return getCountryEssentials(country).currencyCode;
  }

  /// Get country flag emoji
  static String getCountryFlag(String country) {
    return getCountryEssentials(country).flag;
  }

  // ============================================
  // COUNTRY DATA - All FREE, no API needed
  // ============================================

  static final Map<String, CountryEssentials> _countryData = {
    'Malaysia': CountryEssentials(
      country: 'Malaysia',
      flag: '🇲🇾',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      currencyName: 'Malaysian Ringgit',
      emergencyNumber: '999',
      policeNumber: '999',
      ambulanceNumber: '999',
      fireNumber: '994',
      touristPolice: '03-2149 6590',
      embassy: null, // Local country
      timezone: 'GMT+8',
      language: 'Malay',
      electricPlug: 'Type G (UK)',
      voltage: '240V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Hai / Selamat', 'suh-lah-mat'),
        PhraseItem('Thank you', 'Terima kasih', 'teh-ree-mah kah-see'),
        PhraseItem('Yes / No', 'Ya / Tidak', 'yah / tee-dahk'),
        PhraseItem('How much?', 'Berapa?', 'beh-rah-pah'),
        PhraseItem('Delicious', 'Sedap', 'seh-dahp'),
        PhraseItem('Excuse me', 'Maafkan saya', 'mah-ahf-kahn sah-yah'),
        PhraseItem('Where is...?', 'Di mana...?', 'dee mah-nah'),
        PhraseItem('Help!', 'Tolong!', 'toh-long'),
      ],
      usefulApps: [
        AppInfo('Grab', 'Ride-hailing & food delivery', 'grab', 'https://www.grab.com'),
        AppInfo('Touch \'n Go', 'E-wallet & payments', 'touchngo', 'https://www.touchngo.com.my'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Waze', 'Traffic & navigation', 'waze', 'https://www.waze.com'),
      ],
      quickLinks: [
        QuickLink('Tourism Malaysia', 'https://www.malaysia.travel/', '🏝️'),
        QuickLink('Immigration', 'https://www.imi.gov.my/', '🛂'),
        QuickLink('Weather', 'https://www.met.gov.my/', '🌤️'),
      ],
      tippingCustom: 'Tipping not expected, but appreciated for good service (10%)',
      waterSafety: 'Tap water not recommended. Drink bottled water.',
      vaccinations: 'No required vaccinations for most travelers',
    ),

    'Japan': CountryEssentials(
      country: 'Japan',
      flag: '🇯🇵',
      currencyCode: 'JPY',
      currencySymbol: '¥',
      currencyName: 'Japanese Yen',
      emergencyNumber: '110',
      policeNumber: '110',
      ambulanceNumber: '119',
      fireNumber: '119',
      touristPolice: '03-3503-8484',
      embassy: 'Contact your country\'s embassy in Tokyo',
      timezone: 'GMT+9',
      language: 'Japanese',
      electricPlug: 'Type A/B (US style)',
      voltage: '100V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Konnichiwa', 'kon-nee-chee-wah'),
        PhraseItem('Thank you', 'Arigatou gozaimasu', 'ah-ree-gah-toh go-zah-ee-mas'),
        PhraseItem('Yes / No', 'Hai / Iie', 'hai / ee-eh'),
        PhraseItem('Excuse me', 'Sumimasen', 'soo-mee-mah-sen'),
        PhraseItem('How much?', 'Ikura desu ka?', 'ee-koo-rah des-kah'),
        PhraseItem('Delicious', 'Oishii', 'oy-shee'),
        PhraseItem('Where is...?', '...wa doko desu ka?', 'wah doh-koh des-kah'),
        PhraseItem('Help!', 'Tasukete!', 'tah-soo-keh-teh'),
      ],
      usefulApps: [
        AppInfo('Google Maps', 'Navigation (works great in Japan)', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Japan Transit', 'Train schedules', 'japantransit', 'https://japantravel.navitime.com'),
        AppInfo('PayPay', 'Mobile payments', 'paypay', 'https://paypay.ne.jp'),
        AppInfo('Google Translate', 'Camera translation', 'googletranslate', 'https://translate.google.com'),
      ],
      quickLinks: [
        QuickLink('Japan Tourism', 'https://www.japan.travel/', '🗾'),
        QuickLink('JR Pass', 'https://www.jrpass.com/', '🚄'),
        QuickLink('Visa Info', 'https://www.mofa.go.jp/j_info/visit/visa/', '🛂'),
        QuickLink('Japan Rail', 'https://www.hyperdia.com/', '🚃'),
      ],
      tippingCustom: 'Tipping is NOT customary and can be considered rude',
      waterSafety: 'Tap water is safe to drink everywhere',
      vaccinations: 'No required vaccinations',
    ),

    'Thailand': CountryEssentials(
      country: 'Thailand',
      flag: '🇹🇭',
      currencyCode: 'THB',
      currencySymbol: '฿',
      currencyName: 'Thai Baht',
      emergencyNumber: '191',
      policeNumber: '191',
      ambulanceNumber: '1669',
      fireNumber: '199',
      touristPolice: '1155',
      embassy: 'Contact your country\'s embassy in Bangkok',
      timezone: 'GMT+7',
      language: 'Thai',
      electricPlug: 'Type A/B/C (US & Euro)',
      voltage: '220V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Sawadee (ka/krap)', 'sah-wah-dee'),
        PhraseItem('Thank you', 'Khop khun (ka/krap)', 'kop-koon'),
        PhraseItem('Yes / No', 'Chai / Mai', 'chai / mai'),
        PhraseItem('How much?', 'Tao rai?', 'tao-rai'),
        PhraseItem('Delicious', 'Aroi', 'ah-roy'),
        PhraseItem('No spicy', 'Mai phet', 'mai-pet'),
        PhraseItem('Where is...?', '...yoo tee nai?', 'yoo tee nai'),
        PhraseItem('Help!', 'Chuay duay!', 'chuay duay'),
      ],
      usefulApps: [
        AppInfo('Grab', 'Ride-hailing & food delivery', 'grab', 'https://www.grab.com'),
        AppInfo('Bolt', 'Cheaper rides', 'bolt', 'https://bolt.eu'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('PromptPay', 'Local QR payments', 'promptpay', null),
      ],
      quickLinks: [
        QuickLink('Thailand Tourism', 'https://www.tourismthailand.org/', '🏝️'),
        QuickLink('Visa Info', 'https://www.thaiembassy.com/', '🛂'),
        QuickLink('BTS Skytrain', 'https://www.bts.co.th/', '🚇'),
      ],
      tippingCustom: 'Tipping appreciated but not mandatory. 20-50 THB for good service.',
      waterSafety: 'Do NOT drink tap water. Always drink bottled water.',
      vaccinations: 'Hepatitis A & Typhoid recommended',
    ),

    'Singapore': CountryEssentials(
      country: 'Singapore',
      flag: '🇸🇬',
      currencyCode: 'SGD',
      currencySymbol: 'S\$',
      currencyName: 'Singapore Dollar',
      emergencyNumber: '999',
      policeNumber: '999',
      ambulanceNumber: '995',
      fireNumber: '995',
      touristPolice: '1800-255-0000',
      embassy: 'Contact your country\'s embassy',
      timezone: 'GMT+8',
      language: 'English, Mandarin, Malay, Tamil',
      electricPlug: 'Type G (UK)',
      voltage: '230V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Hello / Ni hao', 'nee-how'),
        PhraseItem('Thank you', 'Thank you / Xie xie', 'shieh-shieh'),
        PhraseItem('Yes / No', 'Yes / No (English commonly used)', ''),
        PhraseItem('How much?', 'How much? / Duo shao qian?', 'dwoh-shaow chien'),
        PhraseItem('Delicious', 'Shiok! (Singlish)', 'shee-ok'),
        PhraseItem('Can/Cannot', 'Can lah / Cannot lah', 'can-lah'),
        PhraseItem('Where is...?', 'Where is...?', ''),
        PhraseItem('Excuse me', 'Excuse me / Pai seh', 'pai-seh'),
      ],
      usefulApps: [
        AppInfo('Grab', 'Ride-hailing & food delivery', 'grab', 'https://www.grab.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('SG BusLeh', 'Bus arrival times', 'sgbusleh', null),
        AppInfo('PayLah/PayNow', 'Mobile payments', 'paylah', null),
      ],
      quickLinks: [
        QuickLink('Visit Singapore', 'https://www.visitsingapore.com/', '🦁'),
        QuickLink('MRT Map', 'https://www.lta.gov.sg/content/ltagov/en/map/train.html', '🚇'),
        QuickLink('Immigration', 'https://www.ica.gov.sg/', '🛂'),
      ],
      tippingCustom: 'Tipping not expected. 10% service charge usually included.',
      waterSafety: 'Tap water is safe to drink',
      vaccinations: 'Yellow fever if coming from affected areas',
    ),

    'Indonesia': CountryEssentials(
      country: 'Indonesia',
      flag: '🇮🇩',
      currencyCode: 'IDR',
      currencySymbol: 'Rp',
      currencyName: 'Indonesian Rupiah',
      emergencyNumber: '112',
      policeNumber: '110',
      ambulanceNumber: '118',
      fireNumber: '113',
      touristPolice: '021-526-4073',
      embassy: 'Contact your country\'s embassy in Jakarta',
      timezone: 'GMT+7 to +9 (varies by region)',
      language: 'Indonesian (Bahasa)',
      electricPlug: 'Type C/F (Euro)',
      voltage: '230V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Halo / Selamat', 'hah-low / suh-lah-mat'),
        PhraseItem('Thank you', 'Terima kasih', 'teh-ree-mah kah-see'),
        PhraseItem('Yes / No', 'Ya / Tidak', 'yah / tee-dahk'),
        PhraseItem('How much?', 'Berapa?', 'beh-rah-pah'),
        PhraseItem('Delicious', 'Enak', 'eh-nahk'),
        PhraseItem('Excuse me', 'Permisi', 'per-mee-see'),
        PhraseItem('Where is...?', 'Di mana...?', 'dee mah-nah'),
        PhraseItem('Help!', 'Tolong!', 'toh-long'),
      ],
      usefulApps: [
        AppInfo('Grab', 'Ride-hailing & food delivery', 'grab', 'https://www.grab.com'),
        AppInfo('Gojek', 'Local super-app', 'gojek', 'https://www.gojek.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Traveloka', 'Local booking', 'traveloka', 'https://www.traveloka.com'),
      ],
      quickLinks: [
        QuickLink('Indonesia Tourism', 'https://www.indonesia.travel/', '🏝️'),
        QuickLink('Visa Info', 'https://www.imigrasi.go.id/', '🛂'),
        QuickLink('Bali Guide', 'https://www.bali.com/', '🌴'),
      ],
      tippingCustom: 'Tipping appreciated. 5-10% for restaurants, small tips for guides.',
      waterSafety: 'Do NOT drink tap water. Always drink bottled water.',
      vaccinations: 'Hepatitis A, Typhoid, and Rabies (if rural) recommended',
    ),

    'Vietnam': CountryEssentials(
      country: 'Vietnam',
      flag: '🇻🇳',
      currencyCode: 'VND',
      currencySymbol: '₫',
      currencyName: 'Vietnamese Dong',
      emergencyNumber: '113',
      policeNumber: '113',
      ambulanceNumber: '115',
      fireNumber: '114',
      touristPolice: '069-942-382',
      embassy: 'Contact your country\'s embassy in Hanoi/HCMC',
      timezone: 'GMT+7',
      language: 'Vietnamese',
      electricPlug: 'Type A/C/G (varied)',
      voltage: '220V',
      drivingSide: 'Right',
      phrases: [
        PhraseItem('Hello', 'Xin chào', 'sin chow'),
        PhraseItem('Thank you', 'Cảm ơn', 'kahm uhn'),
        PhraseItem('Yes / No', 'Vâng / Không', 'vung / kohm'),
        PhraseItem('How much?', 'Bao nhiêu?', 'bow nyew'),
        PhraseItem('Delicious', 'Ngon', 'ngon'),
        PhraseItem('Too expensive', 'Đắt quá', 'dat quah'),
        PhraseItem('Where is...?', '...ở đâu?', 'uh dow'),
        PhraseItem('Help!', 'Cứu tôi!', 'koo toy'),
      ],
      usefulApps: [
        AppInfo('Grab', 'Ride-hailing & food delivery', 'grab', 'https://www.grab.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Momo', 'Mobile payments', 'momo', null),
        AppInfo('Traveloka', 'Local booking', 'traveloka', 'https://www.traveloka.com'),
      ],
      quickLinks: [
        QuickLink('Vietnam Tourism', 'https://vietnam.travel/', '🇻🇳'),
        QuickLink('E-Visa', 'https://evisa.xuatnhapcanh.gov.vn/', '🛂'),
        QuickLink('Weather', 'https://nchmf.gov.vn/', '🌤️'),
      ],
      tippingCustom: 'Tipping not traditionally expected but appreciated (10-15%)',
      waterSafety: 'Do NOT drink tap water. Drink bottled or boiled water.',
      vaccinations: 'Hepatitis A & Typhoid recommended',
    ),

    'South Korea': CountryEssentials(
      country: 'South Korea',
      flag: '🇰🇷',
      currencyCode: 'KRW',
      currencySymbol: '₩',
      currencyName: 'South Korean Won',
      emergencyNumber: '112',
      policeNumber: '112',
      ambulanceNumber: '119',
      fireNumber: '119',
      touristPolice: '1330',
      embassy: 'Contact your country\'s embassy in Seoul',
      timezone: 'GMT+9',
      language: 'Korean',
      electricPlug: 'Type C/F (Euro)',
      voltage: '220V',
      drivingSide: 'Right',
      phrases: [
        PhraseItem('Hello', 'Annyeonghaseyo', 'an-nyung-ha-seh-yo'),
        PhraseItem('Thank you', 'Gamsahamnida', 'gam-sa-ham-nee-da'),
        PhraseItem('Yes / No', 'Ne / Aniyo', 'neh / ah-nee-yo'),
        PhraseItem('How much?', 'Eolmayeyo?', 'ul-ma-yeh-yo'),
        PhraseItem('Delicious', 'Mashisseoyo', 'ma-shee-suh-yo'),
        PhraseItem('Excuse me', 'Sillyehamnida', 'shil-leh-ham-nee-da'),
        PhraseItem('Where is...?', '...eodi isseoyo?', 'uh-dee ee-suh-yo'),
        PhraseItem('Help!', 'Dowajuseyo!', 'do-wa-joo-seh-yo'),
      ],
      usefulApps: [
        AppInfo('KakaoMap', 'Best navigation in Korea', 'kakaomap', 'https://map.kakao.com'),
        AppInfo('KakaoTaxi', 'Ride-hailing', 'kakaotaxi', null),
        AppInfo('Naver Map', 'Alternative navigation', 'navermap', 'https://map.naver.com'),
        AppInfo('Papago', 'Translation (better than Google for Korean)', 'papago', null),
      ],
      quickLinks: [
        QuickLink('Korea Tourism', 'https://english.visitkorea.or.kr/', '🇰🇷'),
        QuickLink('K-ETA', 'https://www.k-eta.go.kr/', '🛂'),
        QuickLink('Seoul Metro', 'https://www.seoulmetro.co.kr/', '🚇'),
      ],
      tippingCustom: 'Tipping NOT customary and not expected',
      waterSafety: 'Tap water is safe but locals prefer bottled',
      vaccinations: 'No required vaccinations',
    ),

    'United States': CountryEssentials(
      country: 'United States',
      flag: '🇺🇸',
      currencyCode: 'USD',
      currencySymbol: '\$',
      currencyName: 'US Dollar',
      emergencyNumber: '911',
      policeNumber: '911',
      ambulanceNumber: '911',
      fireNumber: '911',
      touristPolice: null,
      embassy: 'Contact your country\'s embassy in Washington DC',
      timezone: 'GMT-5 to -10 (varies)',
      language: 'English',
      electricPlug: 'Type A/B (US)',
      voltage: '120V',
      drivingSide: 'Right',
      phrases: [
        PhraseItem('Hello', 'Hello / Hi', ''),
        PhraseItem('Thank you', 'Thank you / Thanks', ''),
        PhraseItem('Yes / No', 'Yes / No', ''),
        PhraseItem('How much?', 'How much is this?', ''),
        PhraseItem('Excuse me', 'Excuse me', ''),
        PhraseItem('Where is...?', 'Where is...?', ''),
        PhraseItem('Check please', 'Can I get the check?', ''),
        PhraseItem('Help!', 'Help!', ''),
      ],
      usefulApps: [
        AppInfo('Uber', 'Ride-hailing', 'uber', 'https://www.uber.com'),
        AppInfo('Lyft', 'Ride-hailing', 'lyft', 'https://www.lyft.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Yelp', 'Restaurant reviews', 'yelp', 'https://www.yelp.com'),
      ],
      quickLinks: [
        QuickLink('Visit USA', 'https://www.visittheusa.com/', '🇺🇸'),
        QuickLink('ESTA', 'https://esta.cbp.dhs.gov/', '🛂'),
        QuickLink('TSA', 'https://www.tsa.gov/', '✈️'),
      ],
      tippingCustom: 'Tipping EXPECTED: 18-20% restaurants, \$1-2/bag hotel, 15-20% taxi',
      waterSafety: 'Tap water is generally safe',
      vaccinations: 'No required vaccinations',
    ),

    'United Kingdom': CountryEssentials(
      country: 'United Kingdom',
      flag: '🇬🇧',
      currencyCode: 'GBP',
      currencySymbol: '£',
      currencyName: 'British Pound',
      emergencyNumber: '999',
      policeNumber: '999',
      ambulanceNumber: '999',
      fireNumber: '999',
      touristPolice: null,
      embassy: 'Contact your country\'s embassy in London',
      timezone: 'GMT+0 (GMT+1 summer)',
      language: 'English',
      electricPlug: 'Type G (UK)',
      voltage: '230V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Hello / Hiya', ''),
        PhraseItem('Thank you', 'Thank you / Cheers', ''),
        PhraseItem('Yes / No', 'Yes / No', ''),
        PhraseItem('Excuse me', 'Excuse me / Sorry', ''),
        PhraseItem('Where is...?', 'Where is...?', ''),
        PhraseItem('How much?', 'How much is this?', ''),
        PhraseItem('Bill please', 'Can I have the bill?', ''),
        PhraseItem('Lovely', 'Lovely / Brilliant', ''),
      ],
      usefulApps: [
        AppInfo('Uber', 'Ride-hailing', 'uber', 'https://www.uber.com'),
        AppInfo('Citymapper', 'Best for London transport', 'citymapper', 'https://citymapper.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Trainline', 'Train tickets', 'trainline', 'https://www.thetrainline.com'),
      ],
      quickLinks: [
        QuickLink('Visit Britain', 'https://www.visitbritain.com/', '🇬🇧'),
        QuickLink('Visa Info', 'https://www.gov.uk/check-uk-visa', '🛂'),
        QuickLink('TfL', 'https://tfl.gov.uk/', '🚇'),
      ],
      tippingCustom: 'Tipping optional: 10-15% in restaurants if no service charge',
      waterSafety: 'Tap water is safe to drink',
      vaccinations: 'No required vaccinations',
    ),

    'Australia': CountryEssentials(
      country: 'Australia',
      flag: '🇦🇺',
      currencyCode: 'AUD',
      currencySymbol: 'A\$',
      currencyName: 'Australian Dollar',
      emergencyNumber: '000',
      policeNumber: '000',
      ambulanceNumber: '000',
      fireNumber: '000',
      touristPolice: null,
      embassy: 'Contact your country\'s embassy in Canberra',
      timezone: 'GMT+8 to +11 (varies)',
      language: 'English',
      electricPlug: 'Type I (Australian)',
      voltage: '230V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Hello / G\'day', 'guh-day'),
        PhraseItem('Thank you', 'Thank you / Ta', 'tah'),
        PhraseItem('Yes / No', 'Yes / No / Yeah/Nah', 'yeah/nah'),
        PhraseItem('How much?', 'How much is this?', ''),
        PhraseItem('No worries', 'No worries', ''),
        PhraseItem('Cheers', 'Cheers (thank you/goodbye)', ''),
        PhraseItem('Arvo', 'Afternoon', 'ar-vo'),
        PhraseItem('Barbie', 'Barbecue', 'bar-bee'),
      ],
      usefulApps: [
        AppInfo('Uber', 'Ride-hailing', 'uber', 'https://www.uber.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('TripView', 'Public transport', 'tripview', null),
        AppInfo('Menulog', 'Food delivery', 'menulog', 'https://www.menulog.com.au'),
      ],
      quickLinks: [
        QuickLink('Australia Tourism', 'https://www.australia.com/', '🦘'),
        QuickLink('ETA Visa', 'https://immi.homeaffairs.gov.au/', '🛂'),
        QuickLink('Weather', 'http://www.bom.gov.au/', '🌤️'),
      ],
      tippingCustom: 'Tipping not expected but appreciated for exceptional service',
      waterSafety: 'Tap water is safe to drink',
      vaccinations: 'No required vaccinations',
    ),

    'China': CountryEssentials(
      country: 'China',
      flag: '🇨🇳',
      currencyCode: 'CNY',
      currencySymbol: '¥',
      currencyName: 'Chinese Yuan',
      emergencyNumber: '110',
      policeNumber: '110',
      ambulanceNumber: '120',
      fireNumber: '119',
      touristPolice: '12301',
      embassy: 'Contact your country\'s embassy in Beijing',
      timezone: 'GMT+8',
      language: 'Mandarin Chinese',
      electricPlug: 'Type A/C/I',
      voltage: '220V',
      drivingSide: 'Right',
      phrases: [
        PhraseItem('Hello', 'Nǐ hǎo', 'nee-how'),
        PhraseItem('Thank you', 'Xièxiè', 'shieh-shieh'),
        PhraseItem('Yes / No', 'Shì / Bù shì', 'shih / boo-shih'),
        PhraseItem('How much?', 'Duōshǎo qián?', 'dwoh-shaow chien'),
        PhraseItem('Delicious', 'Hǎo chī', 'how-chih'),
        PhraseItem('Excuse me', 'Bù hǎo yìsi', 'boo-how-ee-sih'),
        PhraseItem('Where is...?', '...zài nǎlǐ?', 'zai nah-lee'),
        PhraseItem('Help!', 'Jiùmìng!', 'jyow-ming'),
      ],
      usefulApps: [
        AppInfo('DiDi', 'Ride-hailing (Uber of China)', 'didi', 'https://www.didiglobal.com'),
        AppInfo('Baidu Maps', 'Navigation (Google blocked)', 'baidumaps', 'https://map.baidu.com'),
        AppInfo('WeChat', 'Messaging & payments (essential!)', 'wechat', 'https://www.wechat.com'),
        AppInfo('Alipay', 'Mobile payments', 'alipay', 'https://www.alipay.com'),
      ],
      quickLinks: [
        QuickLink('China Tourism', 'https://www.travelchina.gov.cn/', '🇨🇳'),
        QuickLink('Visa Info', 'https://www.china-embassy.org/', '🛂'),
        QuickLink('Train Booking', 'https://www.trip.com/trains/', '🚄'),
      ],
      tippingCustom: 'Tipping NOT customary and may even be refused',
      waterSafety: 'Do NOT drink tap water. Drink bottled or boiled water.',
      vaccinations: 'Hepatitis A & B recommended',
    ),

    'Philippines': CountryEssentials(
      country: 'Philippines',
      flag: '🇵🇭',
      currencyCode: 'PHP',
      currencySymbol: '₱',
      currencyName: 'Philippine Peso',
      emergencyNumber: '911',
      policeNumber: '117',
      ambulanceNumber: '911',
      fireNumber: '911',
      touristPolice: '1343',
      embassy: 'Contact your country\'s embassy in Manila',
      timezone: 'GMT+8',
      language: 'Filipino, English',
      electricPlug: 'Type A/B/C',
      voltage: '220V',
      drivingSide: 'Right',
      phrases: [
        PhraseItem('Hello', 'Kamusta', 'kah-moos-tah'),
        PhraseItem('Thank you', 'Salamat', 'sah-lah-maht'),
        PhraseItem('Yes / No', 'Oo / Hindi', 'oh-oh / hin-dee'),
        PhraseItem('How much?', 'Magkano?', 'mahg-kah-noh'),
        PhraseItem('Delicious', 'Masarap', 'mah-sah-rahp'),
        PhraseItem('Excuse me', 'Pakiusap', 'pah-kee-oo-sahp'),
        PhraseItem('Where is...?', 'Nasaan...?', 'nah-sah-ahn'),
        PhraseItem('Help!', 'Tulong!', 'too-long'),
      ],
      usefulApps: [
        AppInfo('Grab', 'Ride-hailing & food delivery', 'grab', 'https://www.grab.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('GCash', 'Mobile wallet', 'gcash', 'https://www.gcash.com'),
        AppInfo('Foodpanda', 'Food delivery', 'foodpanda', 'https://www.foodpanda.ph'),
      ],
      quickLinks: [
        QuickLink('Philippines Tourism', 'https://www.tourism.gov.ph/', '🏝️'),
        QuickLink('eTravel', 'https://etravel.gov.ph/', '🛂'),
        QuickLink('Weather', 'https://www.pagasa.dost.gov.ph/', '🌤️'),
      ],
      tippingCustom: 'Tipping appreciated: 10% in restaurants if no service charge',
      waterSafety: 'Do NOT drink tap water. Drink bottled water.',
      vaccinations: 'Hepatitis A & Typhoid recommended',
    ),

    'India': CountryEssentials(
      country: 'India',
      flag: '🇮🇳',
      currencyCode: 'INR',
      currencySymbol: '₹',
      currencyName: 'Indian Rupee',
      emergencyNumber: '112',
      policeNumber: '100',
      ambulanceNumber: '102',
      fireNumber: '101',
      touristPolice: '1363',
      embassy: 'Contact your country\'s embassy in New Delhi',
      timezone: 'GMT+5:30',
      language: 'Hindi, English',
      electricPlug: 'Type C/D/M',
      voltage: '230V',
      drivingSide: 'Left',
      phrases: [
        PhraseItem('Hello', 'Namaste', 'nah-mah-stay'),
        PhraseItem('Thank you', 'Dhanyavaad', 'dhun-ya-vahd'),
        PhraseItem('Yes / No', 'Haan / Nahin', 'hahn / nah-heen'),
        PhraseItem('How much?', 'Kitna?', 'kit-nah'),
        PhraseItem('Delicious', 'Swadisht', 'swah-disht'),
        PhraseItem('No spicy', 'Mirchi nahin', 'mir-chee nah-heen'),
        PhraseItem('Where is...?', '...kahan hai?', 'kah-hahn hai'),
        PhraseItem('Help!', 'Madad!', 'mah-dahd'),
      ],
      usefulApps: [
        AppInfo('Uber', 'Ride-hailing', 'uber', 'https://www.uber.com'),
        AppInfo('Ola', 'Local ride-hailing', 'ola', 'https://www.olacabs.com'),
        AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
        AppInfo('Paytm', 'Mobile payments', 'paytm', 'https://paytm.com'),
      ],
      quickLinks: [
        QuickLink('Incredible India', 'https://www.incredibleindia.org/', '🇮🇳'),
        QuickLink('e-Visa', 'https://indianvisaonline.gov.in/', '🛂'),
        QuickLink('Railways', 'https://www.irctc.co.in/', '🚃'),
      ],
      tippingCustom: 'Tipping appreciated: 10% in restaurants, small tips for porters',
      waterSafety: 'Do NOT drink tap water. Only drink bottled/filtered water.',
      vaccinations: 'Hepatitis A & Typhoid required, Rabies recommended',
    ),
  };

  static final CountryEssentials _defaultEssentials = CountryEssentials(
    country: 'International',
    flag: '🌍',
    currencyCode: 'USD',
    currencySymbol: '\$',
    currencyName: 'US Dollar (reference)',
    emergencyNumber: '112',
    policeNumber: '112',
    ambulanceNumber: '112',
    fireNumber: '112',
    touristPolice: null,
    embassy: 'Contact your country\'s nearest embassy',
    timezone: 'Check local time',
    language: 'Local language',
    electricPlug: 'Varies - bring universal adapter',
    voltage: 'Varies (110V-240V)',
    drivingSide: 'Varies',
    phrases: [
      PhraseItem('Hello', 'Hello', ''),
      PhraseItem('Thank you', 'Thank you', ''),
      PhraseItem('Yes / No', 'Yes / No', ''),
      PhraseItem('How much?', 'How much?', ''),
      PhraseItem('Help!', 'Help!', ''),
    ],
    usefulApps: [
      AppInfo('Google Maps', 'Navigation', 'googlemaps', 'https://maps.google.com'),
      AppInfo('Google Translate', 'Translation', 'googletranslate', 'https://translate.google.com'),
      AppInfo('XE Currency', 'Currency conversion', 'xe', 'https://www.xe.com'),
    ],
    quickLinks: [
      QuickLink('Visa Info', 'https://www.projectvisa.com/', '🛂'),
      QuickLink('Travel Advisories', 'https://travel.state.gov/', '⚠️'),
    ],
    tippingCustom: 'Check local customs - varies by country',
    waterSafety: 'Check local conditions - when in doubt, drink bottled water',
    vaccinations: 'Consult your doctor for destination-specific recommendations',
  );
}

// ============================================
// DATA CLASSES
// ============================================

class CountryEssentials {
  final String country;
  final String flag;
  final String currencyCode;
  final String currencySymbol;
  final String currencyName;
  final String emergencyNumber;
  final String policeNumber;
  final String ambulanceNumber;
  final String fireNumber;
  final String? touristPolice;
  final String? embassy;
  final String timezone;
  final String language;
  final String electricPlug;
  final String voltage;
  final String drivingSide;
  final List<PhraseItem> phrases;
  final List<AppInfo> usefulApps;
  final List<QuickLink> quickLinks;
  final String tippingCustom;
  final String waterSafety;
  final String vaccinations;

  const CountryEssentials({
    required this.country,
    required this.flag,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyName,
    required this.emergencyNumber,
    required this.policeNumber,
    required this.ambulanceNumber,
    required this.fireNumber,
    this.touristPolice,
    this.embassy,
    required this.timezone,
    required this.language,
    required this.electricPlug,
    required this.voltage,
    required this.drivingSide,
    required this.phrases,
    required this.usefulApps,
    required this.quickLinks,
    required this.tippingCustom,
    required this.waterSafety,
    required this.vaccinations,
  });
}

class PhraseItem {
  final String english;
  final String local;
  final String pronunciation;

  const PhraseItem(this.english, this.local, this.pronunciation);
}

class AppInfo {
  final String name;
  final String description;
  final String id;
  final String? url;

  const AppInfo(this.name, this.description, this.id, this.url);
}

class QuickLink {
  final String title;
  final String url;
  final String emoji;

  const QuickLink(this.title, this.url, this.emoji);
}