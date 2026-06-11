# Dart / Flutter 문법 — C++ 대응표

---

## 1. 변수 선언

| 개념              | C++                    | Dart                |
| ----------------- | ---------------------- | ------------------- |
| 명시적 타입       | `int x = 5;`           | `int x = 5;`        |
| 타입 추론         | `auto x = 5;`          | `var x = 5;`        |
| 상수 (런타임)     | `const int x = 5;`     | `final int x = 5;`  |
| 상수 (컴파일타임) | `constexpr int x = 5;` | `const int x = 5;`  |
| 전역 상수         | `const int MAX = 100;` | `const kMax = 100;` |

```dart
// Dart
var name = 'PixelLens';   // String으로 추론
final width = 32;          // 한 번만 할당 가능 (C++ const와 유사)
const kPixelSize = 24.0;   // 컴파일타임 상수 (C++ constexpr와 유사)
```

> **핵심 차이**: Dart의 `final`은 C++의 `const`, Dart의 `const`는 C++의 `constexpr`에 가깝다.

---

## 2. 타입 시스템

```
C++   → int, float, double, bool, std::string, char
Dart  → int, double, bool, String  (float 없음, char 없음)
```

```dart
int    count = 0;
double ratio = 3.14;
bool   isOn  = true;
String label = 'hello';
```

### Null Safety (C++에 없는 개념)

```cpp
// C++ - 포인터는 기본적으로 null 가능
int* ptr = nullptr;  // 런타임에서야 터짐
```

```dart
// Dart - 컴파일 타임에 null 여부를 강제 구분
int  count = 5;    // null 불가 (기본)
int? maybeNull;    // null 가능 (? 붙여야 함)

// null이면 대신 쓸 값
int result = maybeNull ?? 0;   // C++ : maybeNull ? *maybeNull : 0

// null이 아닐 때만 접근
maybeNull?.toString();         // C++ : if (ptr) ptr->toString();
```

---

## 3. 함수

```cpp
// C++
int add(int a, int b) { return a + b; }
```

```dart
// Dart - 완전히 동일한 형태
int add(int a, int b) { return a + b; }

// 한 줄이면 => 사용 (람다처럼)
int add(int a, int b) => a + b;
```

### Named Parameter (C++에 없음)

```cpp
// C++ - 순서로만 구분
drawRect(10, 20, 100, 50);  // 뭐가 뭔지 모름
```

```dart
// Dart - 이름으로 전달
void drawRect({required int x, required int y, int width = 100}) { ... }

drawRect(x: 10, y: 20);         // 순서 상관없음
drawRect(y: 20, x: 10, width: 50);  // 이렇게도 됨
```

### Optional Parameter

```dart
// [] 안에 넣으면 생략 가능
String greet(String name, [String? title]) {
  return title != null ? '$title $name' : name;
}

greet('지호');          // OK
greet('지호', 'Dr.');   // OK
```

---

## 4. 클래스

```cpp
// C++
class Layer {
public:
    std::string name;
    bool isVisible;

    Layer(std::string n, bool v) : name(n), isVisible(v) {}

    void toggle() { isVisible = !isVisible; }
};
```

```dart
// Dart
class Layer {
  final String name;
  final bool isVisible;

  // 생성자 - this.name 으로 바로 할당 가능
  Layer({required this.name, required this.isVisible});

  void toggle() { /* final이라 직접 변경 불가 → copyWith 패턴 사용 */ }
}
```

### copyWith 패턴 (Dart 관용구)

```cpp
// C++ - 필드 직접 수정
layer.isVisible = false;
```

```dart
// Dart - @immutable이면 새 객체를 만들어서 교체
// (Flutter에서 상태 변경은 항상 이 방식)
Layer copyWith({String? name, bool? isVisible}) => Layer(
  name: name ?? this.name,
  isVisible: isVisible ?? this.isVisible,
);

// 사용
final hidden = layer.copyWith(isVisible: false);
```

### Getter

```cpp
// C++
class Circle {
    double _radius;
public:
    double getArea() { return 3.14 * _radius * _radius; }
};
```

```dart
// Dart - get 키워드
class Circle {
  final double radius;
  Circle(this.radius);

  double get area => 3.14 * radius * radius;  // 함수처럼 쓰지 않고 필드처럼 접근
}

var c = Circle(5.0);
print(c.area);  // c.area() 아님 주의!
```

### 상속

```cpp
// C++
class DrawingLayer : public Layer { ... };
```

```dart
// Dart
class DrawingLayer extends Layer { ... }
```

### sealed class (C++17 std::variant와 유사)

```dart
// 이 타입의 하위 클래스는 같은 파일 안에서만 만들 수 있음
// → switch에서 모든 경우를 강제로 처리해야 함
sealed class Layer {}
final class DrawingLayer     extends Layer {}
final class SegmentationLayer extends Layer {}

// switch - 빠뜨리면 컴파일 에러
switch (layer) {
  case DrawingLayer dl     => print('드로잉');
  case SegmentationLayer sl => print('세그멘테이션');
  // 다른 경우가 없으므로 default 불필요
}
```

---

## 5. 컬렉션

### List (= C++ vector)

```cpp
std::vector<int> v = {1, 2, 3};
v.push_back(4);
v[0];        // 1
v.size();    // 4
```

```dart
List<int> v = [1, 2, 3];
v.add(4);
v[0];        // 1
v.length;    // 4 (메서드 아니고 getter)

// 불변 리스트
final fixed = const [1, 2, 3];  // add() 호출하면 런타임 에러
```

### Map (= C++ unordered_map)

```cpp
std::unordered_map<std::string, int> m;
m["hp"] = 100;
m.count("hp");  // 존재 확인
```

```dart
Map<String, int> m = {};
m['hp'] = 100;
m.containsKey('hp');  // 존재 확인
m['없는키'];           // null 반환 (크래시 아님)
```

### Spread 연산자

```cpp
// C++ - 두 벡터 합치기 (번거로움)
v1.insert(v1.end(), v2.begin(), v2.end());
```

```dart
// Dart - ... 으로 펼치기
final merged = [...list1, ...list2, Colors.red];
```

---

## 6. 람다 / 클로저

```cpp
// C++
auto add = [](int a, int b) { return a + b; };
std::sort(v.begin(), v.end(), [](int a, int b){ return a > b; });
```

```dart
// Dart
var add = (int a, int b) => a + b;
list.sort((a, b) => b - a);  // 내림차순

// map / where / forEach (C++ transform/copy_if/for_each)
final doubled = [1,2,3].map((x) => x * 2).toList();  // [2, 4, 6]
final evens   = [1,2,3,4].where((x) => x % 2 == 0).toList();  // [2, 4]
```

---

## 7. 비동기 (async / await)

```cpp
// C++ - std::future / std::async (복잡함)
auto fut = std::async(std::launch::async, loadFile);
auto result = fut.get();  // 블로킹
```

```dart
// Dart - async/await (JavaScript와 동일한 스타일)
Future<String> loadFile() async {
  final data = await File('image.png').readAsString();  // 기다리는 동안 UI 안 멈춤
  return data;
}

// 호출
void onTap() async {
  final content = await loadFile();
  print(content);
}
```

> **핵심**: `Future<T>`는 C++의 `std::future<T>`와 같은 개념. `async/await`으로 콜백 지옥 없이 씀.

---

## 8. Flutter 전용 개념

### Widget = UI 조각 (불변)

```cpp
// C++ Qt 방식 - 객체 생성 후 직접 조작
QPushButton* btn = new QPushButton("Click");
btn->setText("Changed");  // 직접 수정
```

```dart
// Flutter - Widget은 불변. 상태가 바뀌면 새로 build()
class MyButton extends StatelessWidget {
  final String label;
  const MyButton({required this.label});

  @override
  Widget build(BuildContext context) {
    // 매 프레임 호출될 수 있음 → 가볍게 유지
    return ElevatedButton(
      onPressed: () {},
      child: Text(label),
    );
  }
}
```

### ConsumerWidget (Riverpod 상태 읽기)

```dart
// ref.watch() → 상태 바뀌면 build() 자동 재호출
class PaletteView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);  // 구독

    return Text(palette.activePalette.name);
  }
}
```

### StatefulWidget (로컬 상태)

```dart
// 위젯 내부에만 있는 상태 (스크롤 위치, 텍스트 입력 등)
class Counter extends StatefulWidget {
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;  // C++의 멤버 변수와 같음

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count++),  // setState 안에서 바꿔야 UI 갱신
      child: Text('$_count'),
    );
  }
}
```

---

## 9. 문자열

```cpp
std::string s = "hello " + name;
std::to_string(42);
```

```dart
// 문자열 보간 - $ 또는 ${}
String name = 'PixelLens';
String s = 'hello $name';           // hello PixelLens
String s2 = '${width * 2} pixels';  // 표현식은 ${} 안에
String num = '$count';               // int → String 자동 변환
```

---

## 10. enum

```cpp
// C++
enum class Tool { Pen, Eraser, Fill };
Tool t = Tool::Pen;
```

```dart
// Dart - 메서드/getter도 추가 가능
enum AppTool { pen, eraser, fill }

// extension으로 메서드 추가 (C++에 없는 기능)
extension AppToolX on AppTool {
  String get label => switch (this) {
    AppTool.pen    => '펜',
    AppTool.eraser => '지우개',
    AppTool.fill   => '채우기',
  };
}

AppTool.pen.label;  // '펜'
```

---

## 자주 헷갈리는 것 요약

| 상황            | C++                           | Dart                        |
| --------------- | ----------------------------- | --------------------------- |
| 타입 추론       | `auto`                        | `var`                       |
| 런타임 상수     | `const`                       | `final`                     |
| 컴파일타임 상수 | `constexpr`                   | `const`                     |
| null 가능 타입  | `int*` / `std::optional<int>` | `int?`                      |
| null 기본값     | `ptr ? *ptr : 0`              | `value ?? 0`                |
| null 안전 접근  | `if(ptr) ptr->fn()`           | `ptr?.fn()`                 |
| 배열            | `std::vector<T>`              | `List<T>`                   |
| 해시맵          | `std::unordered_map<K,V>`     | `Map<K,V>`                  |
| 상속            | `: public Base`               | `extends Base`              |
| 인터페이스      | 순수 가상 클래스              | `implements` / `abstract`   |
| 람다            | `[&](int x){ return x; }`     | `(int x) => x`              |
| 비동기          | `std::future`                 | `Future<T>` + `async/await` |
