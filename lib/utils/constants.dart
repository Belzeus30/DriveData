class AppConstants {
  static const List<String> fuelTypes = [
    'Benzín',
    'Diesel',
    'LPG',
    'CNG',
    'Elektro',
    'Hybrid',
  ];

  static const List<String> routeTypes = [
    'city',
    'highway',
    'mixed',
    'offroad',
  ];

  static const Map<String, String> routeTypeLabels = {
    'city': 'Město',
    'highway': 'Dálnice',
    'mixed': 'Kombinovaná',
    'offroad': 'Terén',
  };

  static const List<String> weatherConditions = [
    'clear',
    'rain',
    'snow',
    'fog',
    'wind',
    'hot',
  ];

  static const Map<String, String> weatherLabels = {
    'clear': '☀️ Jasno',
    'rain': '🌧️ Déšť',
    'snow': '❄️ Sníh',
    'fog': '🌫️ Mlha',
    'wind': '💨 Vítr',
    'hot': '🌡️ Horko',
  };

  static const Map<String, String> weatherIcons = {
    'clear': '☀️',
    'rain': '🌧️',
    'snow': '❄️',
    'fog': '🌫️',
    'wind': '💨',
    'hot': '🌡️',
  };

  static const Map<String, String> routeIcons = {
    'city': '🏙️',
    'highway': '🛣️',
    'mixed': '🔀',
    'offroad': '🏔️',
  };

  // ==================== SERVIS ====================

  static const List<String> serviceTypes = [
    'oil',
    'tires',
    'brakes',
    'inspection',
    'battery',
    'filters',
    'belts',
    'other',
  ];

  static const Map<String, String> serviceTypeLabels = {
    'oil': 'Výměna oleje',
    'tires': 'Pneumatiky',
    'brakes': 'Brzdové destičky',
    'inspection': 'STK / Technická',
    'battery': 'Baterie / Akumulátor',
    'filters': 'Filtry (vzduch, kabina)',
    'belts': 'Řemeny / Rozvod',
    'other': 'Ostatní',
  };

  static const Map<String, String> serviceTypeIcons = {
    'oil': '🛢️',
    'tires': '🔄',
    'brakes': '🛑',
    'inspection': '🔍',
    'battery': '🔋',
    'filters': '💨',
    'belts': '⚙️',
    'other': '🔧',
  };

  /// Po kolika měsících navrhnout příští termín (null = nenavrhovat automaticky)
  static const Map<String, int?> serviceNextDueMonths = {
    'oil': 12,
    'tires': 6,
    'brakes': null,
    'inspection': 24,
    'battery': 36,
    'filters': 12,
    'belts': 48,
    'other': null,
  };

  /// Kolik dní předem upozornit (před datem)
  static const Map<String, int> serviceReminderDays = {
    'oil': 14,
    'tires': 14,
    'brakes': 14,
    'inspection': 30,
    'battery': 30,
    'filters': 14,
    'belts': 30,
    'other': 30,
  };

  /// Kolik km předem upozornit (null = nepříhlídnout km)
  static const Map<String, double?> serviceReminderKm = {
    'oil': 1000,
    'tires': 1000,
    'brakes': 1000,
    'inspection': null,
    'battery': null,
    'filters': 2000,
    'belts': 1000,
    'other': 500,
  };

  // ==================== POJISTKY ====================

  static const List<String> insuranceTypes = [
    'pov',
    'comprehensive',
    'vignette',
    'travel',
    'other',
  ];

  static const Map<String, String> insuranceTypeLabels = {
    'pov': 'Povinné ručení (POV)',
    'comprehensive': 'Havarijní pojištění',
    'vignette': 'Dálniční známka',
    'travel': 'Cestovní pojištění',
    'other': 'Jiné',
  };

  static const Map<String, String> insuranceTypeIcons = {
    'pov': '🛡️',
    'comprehensive': '🚗',
    'vignette': '🛣️',
    'travel': '✈️',
    'other': '📜',
  };

  /// Kolik dní předem upozornit na vypršení pojištění
  static const Map<String, int> insuranceReminderDays = {
    'pov': 30,
    'comprehensive': 30,
    'vignette': 14,
    'travel': 7,
    'other': 30,
  };

  // ==================== VOZÍKY ====================

  /// Kolik dní předem upozornit na STK / TP vozíku
  static const int trailerTechReminderDays = 30;

  // ==================== CÍLE ====================

  static const List<String> goalTypes = [
    'fuel',
    'score',
    'km_month',
    'cost_km',
    'trips_month',
  ];

  static const Map<String, String> goalTypeLabels = {
    'fuel': 'Průměrná spotřeba (l/100km)',
    'score': 'Průměrné skóre řidiče',
    'km_month': 'Km za měsíc',
    'cost_km': 'Náklady na km (Kč/km)',
    'trips_month': 'Počet jízd za měsíc',
  };

  static const Map<String, String> goalTypeIcons = {
    'fuel': '⛽',
    'score': '⭐',
    'km_month': '📍',
    'cost_km': '💰',
    'trips_month': '📅',
  };

  static const Map<String, String> goalTypeUnits = {
    'fuel': 'l/100km',
    'score': '/ 10',
    'km_month': 'km',
    'cost_km': 'Kč/km',
    'trips_month': 'jízd',
  };
}
