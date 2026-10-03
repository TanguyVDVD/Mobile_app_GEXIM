// Fil d'arrière-plan de la base locale, côté navigateur.
//
// À compiler vers `web/drift_worker.js` — voir LISEZMOI.md, à côté.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
