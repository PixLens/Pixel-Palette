1. 상태관리(State Management)

현재 시장 점유율 기준으로 보면:

패턴 사용량 특징
Riverpod ★★★★★ 현재 사실상 표준
Bloc ★★★★☆ 대규모 기업 프로젝트
Provider ★★★☆☆ 구형 프로젝트
GetX ★★☆☆☆ 호불호 강함
MobX ★☆☆☆☆ 거의 안 씀

현재 신규 프로젝트면 대부분:

Flutter
└─ Riverpod
└─ StateNotifier / AsyncNotifier

조합을 사용합니다.

예시:

final userProvider =
AsyncNotifierProvider<UserNotifier, User>(
UserNotifier.new);

class UserNotifier extends AsyncNotifier<User> {
@override
Future<User> build() async {
return await repository.loadUser();
}
} 2. 가장 많이 쓰는 프로젝트 구조
Feature First

예전:

lib/
├─ models/
├─ pages/
├─ services/
└─ widgets/

요즘:

lib/
├─ features/
│ ├─ auth/
│ ├─ home/
│ └─ settings/
├─ core/
└─ shared/

각 기능이 독립적인 모듈이 됩니다.

예:

auth/
├─ data/
├─ domain/
├─ presentation/
└─ providers/ 3. Clean Architecture

대규모 앱에서 매우 흔함.

Feature
├─ Data
├─ Domain
└─ Presentation
Data
class UserRepositoryImpl

API 호출

DB 접근

DTO

Domain
class User
abstract class UserRepository
class LoginUseCase

비즈니스 로직

Presentation
class LoginPage
class LoginViewModel

UI

구조:

UI
↓
ViewModel
↓
UseCase
↓
Repository
↓
API 4. Flutter식 Widget 작성 스타일
작은 Widget으로 분리

안 좋은 예:

Widget build() {
return Column(
children: [
...
...
...
...
...
],
);
}

좋은 예:

Widget build() {
return Column(
children: [
const UserHeader(),
const UserProfile(),
const UserMenu(),
],
);
} 5. const 적극 사용

Flutter 개발자들이 매우 중요하게 생각함.

const Text("Hello")
const SizedBox(height: 16)
const UserCard()

빌드 최적화 효과가 있습니다.

6. Extension 적극 활용

매우 흔함.

extension ContextExtension on BuildContext {
ThemeData get theme => Theme.of(this);
}

사용:

context.theme.colorScheme.primary 7. Theme 중심 개발

하드코딩 거의 안 함.

안 좋은 예:

Text(
"Login",
style: TextStyle(
fontSize: 20,
color: Colors.blue,
),
)

좋은 예:

Text(
"Login",
style: context.textTheme.titleLarge,
)
context.colorScheme.primary 8. Navigation

현재는 대부분

go_router

사용

final router = GoRouter(
routes: [
GoRoute(
path: '/',
builder: (context, state) =>
const HomePage(),
),
],
);

이제 Navigator 직접 쓰는 경우는 많지 않습니다.

9. 비동기 처리

Riverpod와 결합

final usersProvider =
FutureProvider<List<User>>((ref) async {
return repository.loadUsers();
});

UI:

ref.watch(usersProvider).when(
data: (users) => UserList(users),
loading: () => const CircularProgressIndicator(),
error: (e, s) => ErrorView(e),
); 10. 실제 현업에서 가장 많이 보이는 조합

스타트업:

Flutter
├─ Riverpod
├─ go_router
├─ freezed
├─ json_serializable
└─ dio

중대형 서비스:

Flutter
├─ Riverpod
├─ Clean Architecture
├─ go_router
├─ freezed
├─ dio
├─ hive / sqlite
└─ Firebase

만약 당신이 지금 Aseprite 스타일의 픽셀아트 라벨링 툴을 Flutter로 만들려는 거라면, 개인적으로는 아래 구조를 추천합니다.

lib/
├─ core/
│ ├─ theme/
│ ├─ router/
│ └─ widgets/
│
├─ features/
│ ├─ project/
│ ├─ canvas/
│ ├─ layer/
│ ├─ segmentation/
│ ├─ export/
│ └─ settings/
│
└─ main.dart

상태관리는 Riverpod, 렌더링은 CustomPainter 또는 필요하면 Flutter에서 네이티브(OpenGL/Metal/Vulkan) 연동을 사용하는 형태가 현재 가장 유지보수하기 좋은 선택입니다.
