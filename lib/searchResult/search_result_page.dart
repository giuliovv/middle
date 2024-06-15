import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/secrets.dart';

class SearchResultPage extends StatelessWidget {
  final String? city1;
  final String? city2;
  final List<bool> selectedDepartureDays;
  final List<bool> selectedReturnDays;
  final DateTimeRange? dateRange;

  const SearchResultPage({
    Key? key,
    this.city1,
    this.city2,
    required this.selectedDepartureDays,
    required this.selectedReturnDays,
    this.dateRange,
  }) : super(key: key);

  Future<Map<String, dynamic>> fetchResults(
      String flyFrom, List<String> cities) async {
    const String tequilaEndpoint = "https://api.tequila.kiwi.com/v2/search";
    final Map<String, String> headers = {"apikey": tequilaApiKey};

    String formattedDateFrom = formatDate(dateRange!.start);
    String formattedDateTo = formatDate(dateRange!.end);
    String departureDayString = createDayString(selectedDepartureDays);
    String returnDayString = createDayString(selectedReturnDays);

    // Create fly_to parameter by joining city names
    String flyToCities = cities.map((city) => "city:$city").join(',');

    final Map<String, dynamic> parameters = {
      "fly_from": "city:$flyFrom",
      "fly_to": flyToCities,
      "date_from": formattedDateFrom,
      "date_to": formattedDateTo,
      "return_from": formattedDateFrom,
      "return_to": formattedDateTo,
      "nights_in_dst_from": "1",
      "nights_in_dst_to": "7",
      "adults": "1",
      "children": "0",
      "infants": "0",
      "max_stopovers": "2",
      "curr": "EUR",
      "max_fly_duration": "3",
      "fly_days": departureDayString,
      "ret_fly_days": returnDayString
    };

    final response = await http.get(
      Uri.parse(tequilaEndpoint).replace(queryParameters: parameters),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<List<Map<String, dynamic>>>
      getAllCommonDestinationAndDateDetails() async {
    List<String> allCities = [
      'LON',
      'CDG',
      'FRA',
      'AMS',
      'MAD',
      'BCN',
      'MUC',
      'FCO',
      'LGW',
      'DME',
      'SVO',
      'ORY',
      'ZRH',
      'CPH',
      'OSL',
      'ARN',
      'DUB',
      'BRU',
      'VIE',
      'MAN',
      'ATH',
      'LIS',
      'HEL',
      'IST',
      'SAW',
      'PRG',
      'BUD',
      'WAW',
      'HAM',
      'EDI',
      'MXP'
    ];
    allCities.remove(city1);
    allCities.remove(city2);

    // Split the city list into chunks
    List<List<String>> cityChunks = [];
    int chunkSize = (allCities.length / 3).ceil();
    for (int i = 0; i < allCities.length; i += chunkSize) {
      cityChunks.add(allCities.sublist(i,
          i + chunkSize > allCities.length ? allCities.length : i + chunkSize));
    }

    // Fetch results for each chunk
    List<Future<Map<String, dynamic>>> futures = [];
    for (var chunk in cityChunks) {
      futures.add(fetchResults(city1!, chunk));
      futures.add(fetchResults(city2!, chunk));
    }

    final responses = await Future.wait(futures);
    List<Map<String, dynamic>> allResults = [];
    for (var response in responses) {
      allResults.addAll(List<Map<String, dynamic>>.from(response['data']));
    }

    // Convert prices to int to avoid double issues
    for (var result in allResults) {
      result['price'] = (result['price'] as num).toInt();
    }

    // Filter common destinations and dates
    List<Map<String, dynamic>> commonFlights =
        findCommonDestinationAndDateFlights(allResults, allResults);

    return commonFlights;
  }

  void printCityCodeToAndDepartureDateAsJson(List<dynamic> result1) {
    List<Map<String, dynamic>> flightsInfo = result1.map((flight) {
      return {
        'destination': flight['cityCodeTo'],
        'departureDate': flight['local_departure'].split('T')[0],
      };
    }).toList();

    String jsonFlightsInfo = json.encode(flightsInfo);
    print(jsonFlightsInfo);
  }

  List<Map<String, dynamic>> findCommonDestinationAndDateFlights(
      List<dynamic> results1, List<dynamic> results2) {
    final Map<String, Map<String, dynamic>> bestFlights = {};

    print(results1.length);
    print(results2.length);

    printCityCodeToAndDepartureDateAsJson(results1);
    printCityCodeToAndDepartureDateAsJson(results2);

    for (var r1 in results1) {
      for (var r2 in results2) {
        if (r1['cityCodeTo'] == r2['cityCodeTo'] &&
            r1['local_arrival'].split('T')[0] ==
                r2['local_arrival'].split('T')[0]) {
          // Common destination
          String pairIdentifier =
              "${r1['cityCodeTo']}-${r1['local_departure'].split('T')[0]}";
          int totalPriceFromCity1 = r1['price'];
          int totalPriceFromCity2 = r2['price'];

          int combinedPrice = totalPriceFromCity1 + totalPriceFromCity2;

          if (!bestFlights.containsKey(pairIdentifier) ||
              (bestFlights[pairIdentifier]!['combinedPrice']) > combinedPrice) {
            bestFlights[pairIdentifier] = {
              'cityCodeTo': r1['cityCodeTo'],
              'totalPriceFromCity1': totalPriceFromCity1,
              'totalPriceFromCity2': totalPriceFromCity2,
              'combinedPrice': combinedPrice,
              'flightFromCity1': r1,
              'flightFromCity2': r2,
            };
          }
        }
      }
    }

    return bestFlights.values.toList();
  }

  List<List<Map<String, dynamic>>> findAllValidFlightPairs(
      List<Map<String, dynamic>> commonFlights) {
    // Sort by total cost for both cities
    commonFlights.sort((a, b) {
      final totalCostA = a['totalPriceFromCity1'] + a['totalPriceFromCity2'];
      final totalCostB = b['totalPriceFromCity1'] + b['totalPriceFromCity2'];
      return totalCostA.compareTo(totalCostB);
    });

    return commonFlights
        .take(5)
        .map((pair) => [
              pair['flightFromCity1'] as Map<String, dynamic>,
              pair['flightFromCity2'] as Map<String, dynamic>
            ])
        .toList();
  }

  bool isMatchingFlightPair(Map<String, dynamic> r1, Map<String, dynamic> r2) {
    return r1['cityCodeFrom'] == city1 &&
        r2['cityCodeFrom'] == city2 &&
        r1['cityCodeTo'] == r2['cityCodeTo'] &&
        r1['local_departure'].split('T')[0] ==
            r2['local_departure'].split('T')[0];
  }

  String createPairIdentifier(
      Map<String, dynamic> r1, Map<String, dynamic> r2) {
    return "${r1['cityCodeFrom']}-${r1['cityCodeTo']}-${r1['local_departure'].split('T')[0]}-${r1['flight_number']}-${r2['flight_number']}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Results'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: getAllCommonDestinationAndDateDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final topFiveCheapestPairs =
                findAllValidFlightPairs(snapshot.data!);

            return ListView.builder(
              itemCount: topFiveCheapestPairs.length,
              itemBuilder: (context, index) {
                var pair = topFiveCheapestPairs[index];
                var flightFromCity1 = pair[0];
                var flightFromCity2 = pair[1];

                return flightFromCity1.isNotEmpty
                    ? FlightCard(
                        city1: city1,
                        city2: city2,
                        flightFromCity1: flightFromCity1,
                        flightFromCity2: flightFromCity2,
                        index: index)
                    : const Text(
                        "No combinations found :( Try a different date range. Less broad is sometimes better");
              },
            );
          } else {
            return const Center(child: Text('No results found'));
          }
        },
      ),
    );
  }
}

String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}

String createDayString(List<bool> selectedDays) {
  if (selectedDays.every((day) => !day)) return "0,1,2,3,4,5,6";

  return selectedDays
      .asMap()
      .entries
      .where((entry) => entry.value)
      .map((entry) => "${(entry.key + 1) % 7}")
      .join(',');
}

class FlightCard extends StatelessWidget {
  final String? city1;
  final String? city2;
  final Map<String, dynamic> flightFromCity1;
  final Map<String, dynamic> flightFromCity2;
  final int index;

  const FlightCard({
    Key? key,
    this.city1,
    this.city2,
    required this.flightFromCity1,
    required this.flightFromCity2,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalPrice = flightFromCity1['price'] + flightFromCity2['price'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              "Option ${index + 1}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text("Common Destination: ${flightFromCity1['cityCodeTo']}"),
            SizedBox(height: 10),
            Text("Round-trip flight details for ${city1}:"),
            Text("Total Price: ${totalPrice}€"),
            Text("Departure: ${flightFromCity1['route'][0]["utc_departure"]}"),
            Text(
                "Duration: ${formatDuration(flightFromCity1['duration']['departure'])}"),
            Text("Return: ${flightFromCity1['route'][1]["utc_departure"]}"),
            Text(
                "Duration: ${formatDuration(flightFromCity1['duration']['return'])}"),
            SizedBox(height: 10),
            Text("Round-trip flight details for ${city2}:"),
            Text("Total Price: ${flightFromCity2['price']}€"),
            Text("Departure: ${flightFromCity2['route'][0]["utc_departure"]}"),
            Text(
                "Duration: ${formatDuration(flightFromCity2['duration']['departure'])}"),
            Text("Return: ${flightFromCity2['route'][1]["utc_departure"]}"),
            Text(
                "Duration: ${formatDuration(flightFromCity2['duration']['return'])}"),
          ],
        ),
      ),
    );
  }
}

String formatDuration(int seconds) {
  int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}
