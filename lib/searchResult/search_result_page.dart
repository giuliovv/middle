import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../auth/secrets.dart';

class SearchResultPage extends StatelessWidget {
  final String? city1;
  final String? city2;
  final List<bool> selectedDays;
  final DateTimeRange? dateRange;

  const SearchResultPage({
    Key? key,
    this.city1,
    this.city2,
    required this.selectedDays,
    this.dateRange,
  }) : super(key: key);

  Future<Map<String, dynamic>> fetchResults(
      String flyFrom, String flyTo, DateTimeRange departureDate) async {
    const String tequilaEndpoint = "https://api.tequila.kiwi.com/v2/search";
    final Map<String, String> headers = {"apikey": tequilaApiKey};
    String dayString = "";

    final String formattedDateFrom =
        dateRange!.start.toIso8601String().split('T')[0]; // Format: yyyy-MM-dd
    final String formattedDateTo =
        dateRange!.end.toIso8601String().split('T')[0]; // Format: yyyy-MM-dd

    for (int i = 0; i < selectedDays.length; i++) {
      if (selectedDays[i]) {
        int adjustedIndex = (i + 1) % 7;
        dayString += "$adjustedIndex";
      }
    }

    if (dayString == "") {
      dayString = "0,1,2,3,4,5,6";
    }

    final Map<String, dynamic> parameters = {
      "fly_from": "city:$flyFrom",
      "fly_to":
          'LHR,CDG,FRA,AMS,MAD,BCN,MUC,FCO,LGW,DME,SVO,ORY,ZRH,CPH,OSL,ARN,DUB,BRU,VIE,MAN,ATH,LIS,HEL,IST,SAW,PRG,BUD,WAW,HAM,EDI,MXP',
      "date_from": formattedDateFrom,
      "date_to": formattedDateTo,
      "adults": "1",
      "children": "0",
      "infants": "0",
      "max_stopovers": "2",
      "curr": "EUR",
      "adult_hold_bag": "0",
      "adult_hand_bag": "0",
      "max_fly_duration": "3",
      // "one_for_city": "true",
      "fly_days": dayString
    };

    final response = await http.get(
        Uri.parse(tequilaEndpoint).replace(queryParameters: parameters),
        headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<List<Map<String, dynamic>>>
      getAllCommonDestinationAndDateDetails() async {
    final future1 = fetchResults(city1!, city2!, dateRange!);
    final future2 = fetchResults(city2!, city1!, dateRange!);

    final responses = await Future.wait([future1, future2]);
    final results1 = responses[0]['data'];
    final results2 = responses[1]['data'];

    return findCommonDestinationAndDateFlights(results1, results2);
  }

  List<Map<String, dynamic>> findCommonDestinationAndDateFlights(
      List<dynamic> results1, List<dynamic> results2) {
    final List<Map<String, dynamic>> commonFlights = [];
    final Set<String> addedPairs = Set<String>();

    for (var r1 in results1) {
      for (var r2 in results2) {
        if (r1['cityCodeFrom'] == city1 &&
            r2['cityCodeFrom'] == city2 &&
            r1['cityCodeTo'] == r2['cityCodeTo'] &&
            r1['local_departure'].split('T')[0] ==
                r2['local_departure'].split('T')[0]) {
          // Create a more detailed unique identifier for the flight pair
          String pairIdentifier =
              "${r1['cityCodeFrom']}-${r1['cityCodeTo']}-${r1['local_departure'].split('T')[0]}-${r1['flight_number']}-${r2['flight_number']}";

          // Check if this pair has already been added
          if (!addedPairs.contains(pairIdentifier)) {
            commonFlights.add({'flightFromCity1': r1, 'flightFromCity2': r2});
            addedPairs.add(pairIdentifier); // Mark this pair as added
          }
        }
      }
    }

    return commonFlights;
  }

  List<List<Map<String, dynamic>>> findAllValidFlightPairs(
      List<Map<String, dynamic>> commonFlights) {
    // Sort the pairs by total price
    commonFlights.sort((a, b) =>
        (a['flightFromCity1']['price'] + a['flightFromCity2']['price'])
            .compareTo(
                b['flightFromCity1']['price'] + b['flightFromCity2']['price']));

    // Select the top 5 cheapest pairs and return them
    return commonFlights
        .take(5)
        .map((pair) => [
              pair['flightFromCity1'] as Map<String, dynamic>,
              pair['flightFromCity2'] as Map<String, dynamic>
            ])
        .toList();
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

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Pair ${index + 1}",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                            "Cheapest flight from ${city1} to ${flightFromCity1['cityTo']}"),
                        Text("Price: ${flightFromCity1['price']}€"),
                        Text(
                            "Departure Date: ${flightFromCity1['local_departure']}"),
                        Text(
                            "Duration: ${formatDuration(flightFromCity1['duration']['departure'])}"),
                        SizedBox(height: 10),
                        Text(
                            "Cheapest flight from ${city2} to ${flightFromCity2['cityTo']}"),
                        Text("Price: ${flightFromCity2['price']}€"),
                        Text(
                            "Departure Date: ${flightFromCity2['local_departure']}"),
                        Text(
                            "Duration: ${formatDuration(flightFromCity2['duration']['departure'])}"),
                      ],
                    ),
                  ),
                );
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

String formatDuration(int seconds) {
  int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}
