# Ticket 08 regression verification run 4

xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core -c "src/core/RenderCore.cpp" -o "build/obj/core/RenderCore.o"
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core -c "src/metal/MetalRenderBackend.mm" -o "build/obj/metal/MetalRenderBackend.o"
src/core/RenderCore.cpp:260:9: error: no matching function for call to object of type 'const (lambda at src/core/RenderCore.cpp:193:28)'
  260 |         markBasic("mode", 20, ParameterRole::Quality);
      |         ^~~~~~~~~
src/core/RenderCore.cpp:193:28: note: candidate function not viable: requires 2 arguments, but 3 were provided
  193 |     const auto markBasic = [&parameters](const char* id, int order) {
      |                            ^             ~~~~~~~~~~~~~~~~~~~~~~~~~
src/core/RenderCore.cpp:261:9: error: no matching function for call to object of type 'const (lambda at src/core/RenderCore.cpp:193:28)'
  261 |         markBasic("density", 30, ParameterRole::Quality);
      |         ^~~~~~~~~
src/core/RenderCore.cpp:193:28: note: candidate function not viable: requires 2 arguments, but 3 were provided
  193 |     const auto markBasic = [&parameters](const char* id, int order) {
      |                            ^             ~~~~~~~~~~~~~~~~~~~~~~~~~
2 errors generated.
make: *** [build/obj/core/RenderCore.o] Error 1
make: *** Waiting for unfinished jobs....
REGRESSION_EXIT_CODE:2
