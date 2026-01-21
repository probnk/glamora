import 'dart:math' as math;
import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

class MathUtils {
  // Mathematical constants
  static const double pi = math.pi;
  static const double twoPi = 2 * math.pi;
  static const double halfPi = math.pi / 2;
  static const double epsilon = 1e-10;

  // Conversion factors
  static const double degreesToRadians = pi / 180;
  static const double radiansToDegrees = 180 / pi;

  /// Linear interpolation between two values
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }

  /// Inverse linear interpolation
  static double inverseLerp(double a, double b, double value) {
    if ((b - a).abs() < epsilon) return 0.0;
    return ((value - a) / (b - a)).clamp(0.0, 1.0);
  }

  /// Clamp a value between min and max
  static double clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  /// Clamp a value between 0 and 1
  static double clamp01(double value) {
    return clamp(value, 0.0, 1.0);
  }

  /// Smooth step interpolation
  static double smoothStep(double t) {
    t = clamp01(t);
    return t * t * (3 - 2 * t);
  }

  /// Smoother step interpolation
  static double smootherStep(double t) {
    t = clamp01(t);
    return t * t * t * (t * (t * 6 - 15) + 10);
  }

  /// Calculate distance between two points
  static double distance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate squared distance (faster, for comparisons)
  static double distanceSquared(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return dx * dx + dy * dy;
  }

  /// Calculate angle between two vectors
  static double angleBetween(Vector2 a, Vector2 b) {
    final dot = a.dot(b);
    final magA = a.length;
    final magB = b.length;

    if (magA < epsilon || magB < epsilon) return 0.0;

    final cosTheta = dot / (magA * magB);
    return math.acos(cosTheta.clamp(-1.0, 1.0));
  }

  /// Calculate signed angle between two vectors (2D)
  static double signedAngle(Vector2 from, Vector2 to) {
    final angle = angleBetween(from, to);
    final cross = from.x * to.y - from.y * to.x;
    return cross >= 0 ? angle : -angle;
  }

  /// Rotate a point around a center
  static Offset rotatePoint(Offset point, Offset center, double angle) {
    final s = math.sin(angle);
    final c = math.cos(angle);

    // Translate point back to origin
    final translatedX = point.dx - center.dx;
    final translatedY = point.dy - center.dy;

    // Rotate point
    final rotatedX = translatedX * c - translatedY * s;
    final rotatedY = translatedX * s + translatedY * c;

    // Translate point back
    return Offset(rotatedX + center.dx, rotatedY + center.dy);
  }

  /// Calculate the midpoint between two points
  static Offset midpoint(Offset a, Offset b) {
    return Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }

  /// Calculate the slope between two points
  static double slope(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    if (dx.abs() < epsilon) return double.infinity;
    return (b.dy - a.dy) / dx;
  }

  /// Calculate intersection point of two lines
  static Offset? lineIntersection(
      Offset a1, Offset a2,
      Offset b1, Offset b2,
      ) {
    final denominator = (a1.dx - a2.dx) * (b1.dy - b2.dy) -
        (a1.dy - a2.dy) * (b1.dx - b2.dx);

    if (denominator.abs() < epsilon) return null; // Lines are parallel

    final t = ((a1.dx - b1.dx) * (b1.dy - b2.dy) -
        (a1.dy - b1.dy) * (b1.dx - b2.dx)) / denominator;

    return Offset(
      a1.dx + t * (a2.dx - a1.dx),
      a1.dy + t * (a2.dy - a1.dy),
    );
  }

  /// Check if a point is inside a polygon
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy)) &&
          (point.dx < (polygon[j].dx - polygon[i].dx) * (point.dy - polygon[i].dy) /
              (polygon[j].dy - polygon[i].dy) + polygon[i].dx)) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// Calculate the centroid of a polygon
  static Offset polygonCentroid(List<Offset> polygon) {
    if (polygon.isEmpty) return Offset.zero;

    double area = 0;
    double cx = 0;
    double cy = 0;

    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final cross = polygon[i].dx * polygon[j].dy - polygon[j].dx * polygon[i].dy;
      area += cross;
      cx += (polygon[i].dx + polygon[j].dx) * cross;
      cy += (polygon[i].dy + polygon[j].dy) * cross;
    }

    area /= 2;
    final factor = 1 / (6 * area);

    return Offset(
      cx * factor,
      cy * factor,
    );
  }

  /// Calculate the bounding rectangle of points
  static Rect boundingRect(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in points) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculate the average of points
  static Offset averagePoint(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;

    double sumX = 0;
    double sumY = 0;

    for (final point in points) {
      sumX += point.dx;
      sumY += point.dy;
    }

    return Offset(sumX / points.length, sumY / points.length);
  }

  /// Calculate the standard deviation of points from their mean
  static double pointStandardDeviation(List<Offset> points, Offset mean) {
    if (points.length < 2) return 0.0;

    double sumSquaredDistances = 0;

    for (final point in points) {
      final distance = MathUtils.distance(point.dx, point.dy, mean.dx, mean.dy);
      sumSquaredDistances += distance * distance;
    }

    return math.sqrt(sumSquaredDistances / (points.length - 1));
  }

  /// Calculate exponential moving average
  static double exponentialMovingAverage(double current, double previous, double alpha) {
    return alpha * current + (1 - alpha) * previous;
  }

  /// Calculate weighted average
  static double weightedAverage(List<double> values, List<double> weights) {
    if (values.isEmpty || values.length != weights.length) return 0.0;

    double sumProducts = 0;
    double sumWeights = 0;

    for (int i = 0; i < values.length; i++) {
      sumProducts += values[i] * weights[i];
      sumWeights += weights[i];
    }

    return sumWeights > 0 ? sumProducts / sumWeights : 0.0;
  }

  /// Calculate the angle of a vector
  static double vectorAngle(Vector2 vector) {
    return math.atan2(vector.y, vector.x);
  }

  /// Normalize an angle to [-π, π]
  static double normalizeAngle(double angle) {
    angle = angle % twoPi;
    if (angle > pi) angle -= twoPi;
    if (angle < -pi) angle += twoPi;
    return angle;
  }

  /// Calculate the shortest angle difference
  static double angleDifference(double a, double b) {
    final diff = normalizeAngle(a - b);
    return normalizeAngle(diff);
  }

  /// Calculate the dot product of two offsets
  static double dotProduct(Offset a, Offset b) {
    return a.dx * b.dx + a.dy * b.dy;
  }

  /// Calculate the cross product of two offsets (2D, returns scalar)
  static double crossProduct(Offset a, Offset b) {
    return a.dx * b.dy - a.dy * b.dx;
  }

  /// Calculate the magnitude of an offset
  static double magnitude(Offset offset) {
    return math.sqrt(offset.dx * offset.dx + offset.dy * offset.dy);
  }

  /// Normalize an offset (make it unit length)
  static Offset normalize(Offset offset) {
    final mag = magnitude(offset);
    if (mag < epsilon) return Offset.zero;
    return Offset(offset.dx / mag, offset.dy / mag);
  }

  /// Calculate the projection of point onto line segment
  static Offset projectPointOntoLine(Offset point, Offset lineStart, Offset lineEnd) {
    final lineVector = Offset(lineEnd.dx - lineStart.dx, lineEnd.dy - lineStart.dy);
    final pointVector = Offset(point.dx - lineStart.dx, point.dy - lineStart.dy);

    final lineLengthSquared = lineVector.dx * lineVector.dx + lineVector.dy * lineVector.dy;
    if (lineLengthSquared < epsilon) return lineStart;

    final t = clamp01((pointVector.dx * lineVector.dx + pointVector.dy * lineVector.dy) / lineLengthSquared);

    return Offset(
      lineStart.dx + t * lineVector.dx,
      lineStart.dy + t * lineVector.dy,
    );
  }

  /// Calculate the distance from a point to a line segment
  static double distanceToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final projection = projectPointOntoLine(point, lineStart, lineEnd);
    return distance(point.dx, point.dy, projection.dx, projection.dy);
  }

  /// Calculate the area of a triangle
  static double triangleArea(Offset a, Offset b, Offset c) {
    return ((b.dx - a.dx) * (c.dy - a.dy) - (c.dx - a.dx) * (b.dy - a.dy)).abs() / 2;
  }

  /// Calculate the circumcenter of a triangle
  static Offset triangleCircumcenter(Offset a, Offset b, Offset c) {
    final d = 2 * (a.dx * (b.dy - c.dy) + b.dx * (c.dy - a.dy) + c.dx * (a.dy - b.dy));

    if (d.abs() < epsilon) return Offset.zero; // Points are collinear

    final ux = ((a.dx * a.dx + a.dy * a.dy) * (b.dy - c.dy) +
        (b.dx * b.dx + b.dy * b.dy) * (c.dy - a.dy) +
        (c.dx * c.dx + c.dy * c.dy) * (a.dy - b.dy)) / d;

    final uy = ((a.dx * a.dx + a.dy * a.dy) * (c.dx - b.dx) +
        (b.dx * b.dx + b.dy * b.dy) * (a.dx - c.dx) +
        (c.dx * c.dx + c.dy * c.dy) * (b.dx - a.dx)) / d;

    return Offset(ux, uy);
  }

  /// Calculate the incenter of a triangle
  static Offset triangleIncenter(Offset a, Offset b, Offset c) {
    final ab = distance(a.dx, a.dy, b.dx, b.dy);
    final bc = distance(b.dx, b.dy, c.dx, c.dy);
    final ca = distance(c.dx, c.dy, a.dx, a.dy);

    final perimeter = ab + bc + ca;
    if (perimeter < epsilon) return a;

    final ix = (bc * a.dx + ca * b.dx + ab * c.dx) / perimeter;
    final iy = (bc * a.dy + ca * b.dy + ab * c.dy) / perimeter;

    return Offset(ix, iy);
  }

  /// Calculate the circumradius of a triangle
  static double triangleCircumradius(Offset a, Offset b, Offset c) {
    final area = triangleArea(a, b, c);
    final ab = distance(a.dx, a.dy, b.dx, b.dy);
    final bc = distance(b.dx, b.dy, c.dx, c.dy);
    final ca = distance(c.dx, c.dy, a.dx, a.dy);

    if (area < epsilon) return 0.0;

    return (ab * bc * ca) / (4 * area);
  }

  /// Calculate the inradius of a triangle
  static double triangleInradius(Offset a, Offset b, Offset c) {
    final area = triangleArea(a, b, c);
    final perimeter = distance(a.dx, a.dy, b.dx, b.dy) +
        distance(b.dx, b.dy, c.dx, c.dy) +
        distance(c.dx, c.dy, a.dx, a.dy);

    if (perimeter < epsilon) return 0.0;

    return 2 * area / perimeter;
  }

  /// Calculate the aspect ratio of a rectangle
  static double aspectRatio(double width, double height) {
    if (height.abs() < epsilon) return double.infinity;
    return width / height;
  }

  /// Calculate the golden ratio point between two values
  static double goldenRatioPoint(double a, double b) {
    final phi = (1 + math.sqrt(5)) / 2;
    return a + (b - a) / phi;
  }

  /// Calculate the factorial of a number
  static int factorial(int n) {
    if (n <= 1) return 1;
    int result = 1;
    for (int i = 2; i <= n; i++) {
      result *= i;
    }
    return result;
  }

  /// Calculate combinations (n choose k)
  static int combinations(int n, int k) {
    if (k < 0 || k > n) return 0;
    if (k > n - k) k = n - k;

    int result = 1;
    for (int i = 1; i <= k; i++) {
      result = result * (n - k + i) ~/ i;
    }
    return result;
  }

  /// Calculate permutations (nPk)
  static int permutations(int n, int k) {
    if (k < 0 || k > n) return 0;

    int result = 1;
    for (int i = 0; i < k; i++) {
      result *= (n - i);
    }
    return result;
  }

  /// Calculate the determinant of a 2x2 matrix
  static double determinant2x2(double a, double b, double c, double d) {
    return a * d - b * c;
  }

  /// Solve a system of 2 linear equations
  static (double, double)? solveLinearSystem2(
      double a1, double b1, double c1,
      double a2, double b2, double c2,
      ) {
    final det = determinant2x2(a1, b1, a2, b2);
    if (det.abs() < epsilon) return null;

    final x = determinant2x2(c1, b1, c2, b2) / det;
    final y = determinant2x2(a1, c1, a2, c2) / det;

    return (x, y);
  }

  /// Convert degrees to radians
  static double toRadians(double degrees) {
    return degrees * degreesToRadians;
  }

  /// Convert radians to degrees
  static double toDegrees(double radians) {
    return radians * radiansToDegrees;
  }

  /// Round a number to specified decimal places
  static double roundTo(double value, int decimalPlaces) {
    final factor = math.pow(10, decimalPlaces);
    return (value * factor).roundToDouble() / factor;
  }
}