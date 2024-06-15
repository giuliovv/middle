import 'package:flutter/material.dart';
import 'searchResult/search_result_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meet Halfway',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Meet Halfway'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? selectedCity1;
  String? selectedCity2;
  List<bool> isSelectedDeparture = List.generate(7, (_) => false);
  List<bool> isSelectedReturn = List.generate(7, (_) => false);
  DateTimeRange? dateRange;

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2025),
      initialDateRange: dateRange,
    );
    if (picked != null) {
      setState(() {
        dateRange = picked;
      });
    }
  }

  Widget _buildDaySelection(List<bool> isSelected, String title) {
    return Column(
      children: [
        Text(title),
        ToggleButtons(
          children: const <Widget>[
            Text('Mon'),
            Text('Tue'),
            Text('Wed'),
            Text('Thu'),
            Text('Fri'),
            Text('Sat'),
            Text('Sun'),
          ],
          isSelected: isSelected,
          onPressed: (int index) {
            setState(() {
              isSelected[index] = !isSelected[index];
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/images/icon.png',
                width: 100,
                height: 100,
              ),
              Text(
                'Find the best meeting point!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Your City',
                    border: OutlineInputBorder(),
                  ),
                  items: <String>['ZRH', 'LON', 'VIE', 'MAD', 'VCE', 'BLQ']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      selectedCity1 = value;
                    });
                  }),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Friend\'s City',
                    border: OutlineInputBorder(),
                  ),
                  items: <String>['ZRH', 'LON', 'VIE', 'MAD', 'VCE', 'BLQ']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                      selectedCity2 = value;
                    });
                  }),
              SizedBox(height: 20),
              _buildDaySelection(isSelectedDeparture, 'Departure Days'),
              _buildDaySelection(isSelectedReturn, 'Return Days'),
              ElevatedButton(
                onPressed: _selectDateRange,
                child: const Text("Select Date Range"),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchResultPage(
                        city1: selectedCity1,
                        city2: selectedCity2,
                        selectedDepartureDays: isSelectedDeparture,
                        selectedReturnDays: isSelectedReturn,
                        dateRange: dateRange,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Search"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
