import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    const String tequilaApiKey = "IgGcMhwu7VqPJEfGjIyg8FJzzwAe0E92";
    final Map<String, String> headers = {"apikey": tequilaApiKey};

    final String formattedDateFrom =
        dateRange!.start.toIso8601String().split('T')[0]; // Format: yyyy-MM-dd
    final String formattedDateTo =
        dateRange!.end.toIso8601String().split('T')[0]; // Format: yyyy-MM-dd

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
      "one_for_city": "true"
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
      getCheapestCommonDestinationAndDateDetails() async {
    final future1 = fetchResults(city1!, city2!, dateRange!);
    final future2 = fetchResults(city2!, city1!, dateRange!);

    final responses = await Future.wait([future1, future2]);
    final results1 = responses[0]['data'];
    final results2 = responses[1]['data'];

    final commonFlights =
        findCommonDestinationAndDateFlights(results1, results2);
    if (commonFlights.isEmpty) {
      throw Exception('No common destinations with matching dates found');
    }

    final cheapestPair = findCheapestFlightPair(commonFlights);
    return cheapestPair;
  }

  List<Map<String, dynamic>> findCommonDestinationAndDateFlights(
      List<dynamic> results1, List<dynamic> results2) {
    final List<Map<String, dynamic>> commonFlights = [];

    for (var r1 in results1) {
      for (var r2 in results2) {
        if (r1['cityTo'] == r2['cityTo'] &&
            r1['local_departure'].split('T')[0] ==
                r2['local_departure'].split('T')[0]) {
          commonFlights.add(r1 as Map<String, dynamic>);
          commonFlights.add(r2 as Map<String, dynamic>);
        }
      }
    }

    return commonFlights;
  }

  List<Map<String, dynamic>> findCheapestFlightPair(
      List<Map<String, dynamic>> commonFlights) {
    double minTotalPrice = double.infinity;
    List<Map<String, dynamic>> cheapestPair = [];

    for (var flightFromCity1
        in commonFlights.where((f) => f['cityCodeFrom'] == city1)) {
      for (var flightFromCity2 in commonFlights.where((f) =>
          f['cityCodeFrom'] == city2 &&
          f['cityTo'] == flightFromCity1['cityTo'])) {
        if (flightFromCity1['local_departure'].split('T')[0] ==
            flightFromCity2['local_departure'].split('T')[0]) {
          double totalPrice =
              flightFromCity1['price'] + flightFromCity2['price'];
          if (totalPrice < minTotalPrice) {
            minTotalPrice = totalPrice;
            cheapestPair = [flightFromCity1, flightFromCity2];
          }
        }
      }
    }

    return cheapestPair;
  }

  List<List<Map<String, dynamic>>> findAllValidFlightPairs(
      List<Map<String, dynamic>> commonFlights) {
    List<Map<String, dynamic>> validPairs = [];

    for (var flightFromCity1
        in commonFlights.where((f) => f['cityCodeFrom'] == city1)) {
      for (var flightFromCity2 in commonFlights.where((f) =>
          f['cityCodeFrom'] == city2 &&
          f['cityTo'] == flightFromCity1['cityTo'])) {
        if (flightFromCity1['local_departure'].split('T')[0] ==
            flightFromCity2['local_departure'].split('T')[0]) {
          validPairs.add({
            'totalPrice': flightFromCity1['price'] + flightFromCity2['price'],
            'flightFromCity1': flightFromCity1,
            'flightFromCity2': flightFromCity2
          });
        }
      }
    }

    // Sort the pairs by total price
    validPairs.sort((a, b) => a['totalPrice'].compareTo(b['totalPrice']));

    // Select the top 5 cheapest pairs and return them as List<Map<String, dynamic>>
    return validPairs
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
        future: getCheapestCommonDestinationAndDateDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final topFiveCheapestPairs =
                findAllValidFlightPairs(snapshot.data!);

            // Construct result text for each pair and concatenate
            String resultText = '';
            for (var i = 0; i < topFiveCheapestPairs.length; i++) {
              var pair = topFiveCheapestPairs[i];
              var flightFromCity1 = pair[0];
              var flightFromCity2 = pair[1];

              resultText += "Pair ${i + 1}:\n"
                  "Cheapest flight from ${city1} to ${flightFromCity1['cityTo']}:\n"
                  "Price: ${flightFromCity1['price']}€\n"
                  "Departure Date: ${flightFromCity1['local_departure']}\n"
                  "Duration: ${formatDuration(flightFromCity1['duration']["departure"])}\n\n"
                  "Cheapest flight from ${city2} to ${flightFromCity2['cityTo']}:\n"
                  "Price: ${flightFromCity2['price']}€\n"
                  "Departure Date: ${flightFromCity2['local_departure']}\n"
                  "Duration: ${formatDuration(flightFromCity2['duration']["departure"])}\n\n";
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(resultText),
              ),
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
