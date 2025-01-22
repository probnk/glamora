import 'package:googleapis_auth/auth_io.dart';

class GetServerKey {
  Future<String> getServerKeyToken() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];

    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": "glamora-c4094",
        "private_key_id": "26d2d520a0f4ded9fcca65d6448956c9b9f49413",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQCoUT8RWjiCqKud\nO5gfWsS4VG1LOLMi9GZdDki1LZ+XTeMTtF2n3F2ZU7JbrddW23DJ9VHzQQ6enlZ6\n+EDs+6hRi92sreA1epor2+dsT0nSfk7JFc74+oK8xKvz/9JC2pYbWW1gY7qy1FAJ\nBfNIa+6VZgzAESEbeHZxSqjJm/HBtcwqjrtnHjAlhkVJpZlfJPwd0pRQFJ4PW859\n+wByum+wnbksegU+f7xOjB7BIvg9YhS9WwQ/KEbyqOWQDUIqpXq1OKXHGBWp1Y8D\nA1hsLCEibVrSpsIfBPuIwc9TjnCvVvaY+onw0Poq9MqssIsqEESNFj04BNloHjtU\neRJ7TRrbAgMBAAECggEAQ9BsJQ0hDH9xmUlL6oITFSMq364p+nDWlzJsl9aYYIkI\nbsVyIHH4IhDnIOnjA0MpZ60XxfaVsdGgjS3dVr2z3JsKBosNdO5/FCGm1WwClbS/\nAGRxfb3Mk8p3bzjIWZgg90bp+vZjX66Lyn7jvG+D8hxqEa41FRDNQ6rtY0EZv83c\nSBumyO7yDsXPxHqOvvFPH5HLIoof1zvUn8quOHd3d+JrqCVZF691A1XEA1o1ImOM\nE9txxrd0quvojEHj9FjXJVXiGK7WqnhVzOvWWQBVNqxvwZjsZDsN28ohhX9xYQ34\n/HxndeWXfh0EE3QZqVRtlHkzimn64kuCPQ6r7cg/EQKBgQDaSgtNGhetOikj25yp\nAXGs441mfICZihLDrmZykH4rDVzxhJk+YfO3eKdteUbkBTomZ9xFKlFiC8/+Drsb\nopTprearahy/h4ryOIkCx8RcyimF2THyJc+w779LbXDJxic1LAFLxAxbISrlRiKP\nzlUalMT+j7Z3aPJSU4+wWoSmUQKBgQDFZSuT6b0BpkzrbJFZkKdUjTCzVSYUKliv\n31jF1X+x4FRsFnP8+cDsn5yEZmIcrXZ0JRJWQQsAtEpSB+W4i6dqgKbo3M4zjXfk\nTlK6AAAGZh964p4DQ9pacjqJXuLJvwXmhnQ2xQNbGeW4RifwArjuF7j9RqUiNCmN\ny1JYTqFnawKBgQDZYvfSNvPxTYR+80wWexur44mD0OV5AqohOeNIoGElms8+rqC2\nIXJG+t8yBJ72ocYBTVltf/FARSdDiYQIx2apOMgJWUl77A4Rnv/DRxJkneewJla5\nIbKuMHQ/N6QlLTMKnuJDg+ASOPuxDKGKuR7Ds/hi0tgSHu+D0Te9lseXoQKBgQCx\nqGSYM36QxYPlP0lyOubfClQSk0g6TgKUB4h2Rbkv9p8EyRCLVp10WhMcdqlG9jfu\nQI9IYjHs6FcbjVAL0GVVTYTrgA92BpUpPfTmwqlDGRasGtnsRl13medlS6kBupMs\n70YZJSfoDl7agwne0hRu9ZrhGXv2VMwxehUatWo/EQKBgQCTa3kOJIB6Z+TK1Udq\n8xIdY4MdAKJ9nd71FeWJgEuW7Xw/Ufwb15WuYDwwZXqFtNeBl8gcJEAyjal0dIfa\njWIjNklOIa22kEWkSd0lsdlL/SjUVgyY2+q3hTNtsmq6bJ8p6lgBemViJvs6qL7q\njW1AFzt/3eMU20zmKSKx9VYrMw==\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-1odg6@glamora-c4094.iam.gserviceaccount.com",
        "client_id": "109791444719814472214",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-1odg6%40glamora-c4094.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com"
      }),
      scopes,
    );
    final accessServerKey = client.credentials.accessToken.data;
    return accessServerKey;
  }
}
