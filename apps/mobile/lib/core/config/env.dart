class Env {

  Env._();



  static late final String apiBaseUrl;

  static late final String publicWebUrl;



  static void load() {

    const apiUrl = String.fromEnvironment(

      'API_BASE_URL',

      defaultValue: 'http://10.0.2.2:3001',

    );

    const webUrl = String.fromEnvironment(

      'PUBLIC_WEB_URL',

      defaultValue: 'http://localhost:3000',

    );



    apiBaseUrl = apiUrl;

    publicWebUrl = webUrl;

  }



  static String publicPropertyUrl(String slug) => '$publicWebUrl/p/$slug';



  /// Tur paylaşım linki (API-only modda PUBLIC_WEB_URL = API adresi).
  static String publicTourUrl(String slug) => '$publicWebUrl/tour/$slug';

  /// Marzipano önizleyici (API üzerinde /viewer.html — Vercel şart değil).
  static String get tourViewerUrl => '$apiBaseUrl/viewer.html';

}

