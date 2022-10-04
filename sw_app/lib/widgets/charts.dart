import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/math_addons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../utils/datatypes.dart';
import '../utils/constants.dart' as _constants;


class Charts extends StatefulWidget{
  const Charts({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Charts> {
  final _modelFile = 'model.tflite';
  double x = 0,
      y = 0,
      z = 0;
  int classPred = 0;
  String direction = "none";
  int maxLen = 50;
  var input = List<double>.filled(150, 0).reshape([1, 50, 3]);

  // initialize FPS
  double fpsValue = 0.0;
  int count = 0;
  double timer = 0.0;
  double smoothing = 0.1;
  double val = 0.0;
  int elapsedFrames = 0;

  // chart plotter variables
  final xPoints = <FlSpot>[];
  final yPoints = <FlSpot>[];
  final zPoints = <FlSpot>[];
  final fpsPoints = <FlSpot>[];
  double xValue = 0;
  double step = 0.05;

  // to track FPS
  Stopwatch stopwatch = Stopwatch()..start();

  // TensorFlow Lite Interpreter object
  late Interpreter _interpreter;

  late final _accelSubscription;

  void _loadModel() async {
    // Creating the interpreter using Interpreter.fromAsset
    _interpreter = await Interpreter.fromAsset(_modelFile);
    if (kDebugMode) {
      print('Interpreter loaded successfully');
    }
  }

  void _run() async {
    final _stream = await SensorManager().sensorUpdates(
      sensorId: Sensors.ACCELEROMETER,
      interval: Sensors.SENSOR_DELAY_GAME,
    );

    // initialize lists
    xPoints.add(FlSpot(xValue, 0));
    yPoints.add(FlSpot(xValue, 0));
    zPoints.add(FlSpot(xValue, 0));
    fpsPoints.add(FlSpot(xValue, 25));  // @TODO: hard-coded init

    _accelSubscription = _stream.listen((sensorEvent) {
      setState(() {
        final _accelData = sensorEvent.data;

        // update counter - relevant for FPS counter
        count++;
        xValue++;

        // get coordinates
        x = _accelData[0];
        y = _accelData[1];
        z = _accelData[2];

        // add accelerator data to tensor and remove oldest sample
        input[0].insert(0, [x, y, z]);
        input[0].removeAt(maxLen);

        // initialize zeros list container to store result from interpreter
        var output = List<double>.filled(20, 0).reshape([1, 20]);

        // run model and store result in output
        _interpreter.run(input, output);

        // get final class prediction by argmax the softmax output
        classPred = argmax(output[0]);

        // update FPS counter every second
        if (stopwatch.elapsedMilliseconds > 1000) {
          double currFreq = count / (stopwatch.elapsedMilliseconds / 1000);
          fpsValue = (fpsValue * smoothing) + currFreq * (1 - smoothing);

          // store result in history
          while ((fpsPoints.length > _constants.limitCount) && (fpsPoints.isNotEmpty)) {
            xPoints.removeAt(0);
            yPoints.removeAt(0);
            zPoints.removeAt(0);
            fpsPoints.removeAt(0);
          }
          xPoints.add(FlSpot(xValue, x));
          yPoints.add(FlSpot(xValue, y));
          zPoints.add(FlSpot(xValue, z));
          fpsPoints.add(FlSpot(xValue, fpsValue));

          // reset stopwatch
          stopwatch.reset();

          // reset counter
          count = 0;
        }
      });
    });
  }

  SizedBox makeLineChart(List<FlSpot> points, Color currColor) {
      return SizedBox(
        width: 350,
        height: 150,
        child: LineChart(
          LineChartData(
            minY: points.map((abc) => abc.y).reduce(min),
            maxY: points.map((abc) => abc.y).reduce(max),
            minX: points.first.x,
            maxX: points.last.x,
            lineTouchData: LineTouchData(enabled: false),
            clipData: FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
            ),
            lineBarsData: [
              historyLine(points, currColor),
            ],
            titlesData: FlTitlesData(
              show: true,
            ),
          ),
        ),
      );
    }

  @override
  void initState() {
    // load model
    _loadModel();

    // run model using accelerometer data
    _run();

    // @TODO: Need to add mechanism to close accelerometer listener when done
    //_accelSubscription.cancel();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
          child: Column(
            children: <Widget>[
              const SizedBox(
                height: 30,
                width: 20,
              ),
              SizedBox(
                width: double.infinity,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 20.0,
                      color: Colors.black,
                    ),
                    children: <TextSpan>[
                      TextSpan(text: "Real time charts: "),
                      TextSpan(text: 'x ', style: TextStyle(color: _constants.xColor)),
                      TextSpan(text: 'y ', style: TextStyle(color: _constants.yColor)),
                      TextSpan(text: 'z ', style: TextStyle(color: _constants.zColor)),
                      TextSpan(
                          text: 'FPS ', style: TextStyle(color: _constants.fpsColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
                width: 20,
              ),
              makeLineChart(xPoints, _constants.xColor),
              makeLineChart(yPoints, _constants.yColor),
              makeLineChart(zPoints, _constants.zColor),
              makeLineChart(fpsPoints, _constants.fpsColor),
            ],
          ),
    );
  }
}