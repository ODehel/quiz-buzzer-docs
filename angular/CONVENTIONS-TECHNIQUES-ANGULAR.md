# CONVENTIONS-TECHNIQUES-ANGULAR.md

## 📋 Stack technique

| Élément | Choix |
|---|---|
| Framework | Angular 21 LTS |
| Langage | TypeScript strict (`strict: true`, `noImplicitAny: true`) |
| Composants | Standalone components uniquement — aucun NgModule |
| State management | Angular Signals (`signal`, `computed`, `effect`) |
| Flux asynchrones | RxJS uniquement pour WebSocket et HTTP long-running |
| Tests unitaires | Jest + `@angular/core/testing` |
| Tests de composants | Angular Testing Library (`@testing-library/angular`) |
| Linting | ESLint + `@angular-eslint` |
| Formatage | Prettier (config partagée avec le serveur Node.js) |

---

## ⚠️ Exigence fondamentale — KISS, DRY, YAGNI, SOLID

Identique à `CONVENTIONS-TECHNIQUES.md` serveur. Ces principes s'appliquent sans exception à l'ensemble du code Angular.

---

## 📁 Nommage des fichiers

La règle générale est `<domaine>-<qualificatif>.<type>.ts`.

| Type | Convention | Exemple |
|---|---|---|
| Composant | `<nom>.component.ts` | `question-form.component.ts` |
| Service | `<nom>.service.ts` | `game-state.service.ts` |
| Guard | `<nom>.guard.ts` | `active-game.guard.ts` |
| Intercepteur | `<nom>.interceptor.ts` | `auth.interceptor.ts` |
| Modèle / interface | `<domaine>.models.ts` | `game.models.ts` |
| Route config | `<zone>.routes.ts` | `app.routes.ts` |
| Constantes | `<domaine>.constants.ts` | `websocket.constants.ts` |
| Test unitaire | `<nom>.spec.ts` | `game-state.service.spec.ts` |
| Test de composant | `<nom>.component.spec.ts` | `quiz-form.component.spec.ts` |

Aucun suffixe `module`, `pipe`, `directive` — non utilisés dans ce projet (YAGNI).

---

## 🏷️ Nommage des symboles TypeScript

### Classes et interfaces

```typescript
// Composants — PascalCase + suffixe Component
export class QuestionFormComponent { }
export class McqControlComponent { }

// Services — PascalCase + suffixe Service
export class GameStateService { }
export class WebSocketService { }

// Guards — camelCase (fonctions, pas des classes)
export const activeGameGuard: CanActivateFn = () => { };

// Interfaces — PascalCase, pas de préfixe I
export interface GameState { }
export interface PlayerAnswer { }

// Types union — PascalCase
export type GameStatus = 'PENDING' | 'OPEN' | ...;
export type QuestionType = 'MCQ' | 'SPEED';

// Enums — évités (préférer les types union, plus légers)
```

### Signals et computed

```typescript
// Signals privés — préfixe underscore + nom camelCase
private readonly _state = signal<GameState>(INITIAL_STATE);
private readonly _token = signal<string | null>(null);

// Signals publics en lecture seule — pas de préfixe
readonly status   = computed(() => this._state().status);
readonly isActive = computed(() => { ... });
readonly isReady  = signal(false);  // writable public : cas rares, justifiés

// Jamais de signal writable public non maîtrisé
// ✅ this._state.update(s => ({ ...s, ...patch }))  via méthode publique
// ❌ this.state.set(...)  depuis l'extérieur du service
```

### Signal inputs et outputs (Angular 21)

```typescript
// Inputs — utiliser input() / input.required() au lieu de @Input()
readonly status = input.required<GameStatus>();         // obligatoire
readonly page = input(1);                                // avec valeur par défaut

// Outputs — utiliser output() au lieu de @Output() + EventEmitter
readonly pageChange = output<number>();                  // émet des valeurs
readonly close = output<void>();                         // émet sans valeur

// Usage dans le template — identique
// <app-paginator [page]="currentPage()" (pageChange)="onPage($event)" />
```

### Observables

```typescript
// Observables — suffixe dollar
readonly messages$ = this.ws.messages$;
readonly errors$   = this._errors$.asObservable();

// Sujets privés — préfixe underscore + suffixe dollar
private readonly _destroy$ = new Subject<void>();
```

### Méthodes

```typescript
// Handlers d'événements UI — préfixe on + PascalCase
onSubmit(): void { }
onDeleteClick(id: string): void { }

// Handlers de messages WS — préfixe on + PascalCase du type de message
private onQuestionTitle(msg: QuestionTitleMessage): void { }
private onBuzzLocked(msg: BuzzLockedMessage): void { }

// Actions envoyées au serveur — verbe + complément
sendTriggerTitle(): void { this.ws.send({ type: 'trigger_title' }) }
sendValidateAnswer(): void { }
```

---

## 🧱 Structure d'un composant standalone

Ordre canonique dans chaque fichier `.component.ts` :

```typescript
// 1. Imports Angular / RxJS
// 2. Imports du projet (services, modèles, composants partagés)

@Component({
  selector: 'app-question-form',       // toujours préfixe app-
  imports: [ /* dépendances directes uniquement */ ],
  templateUrl: './question-form.component.html',   // template TOUJOURS dans un fichier dédié
  styleUrl: './question-form.component.css',       // styles TOUJOURS dans un fichier dédié
  changeDetection: ChangeDetectionStrategy.OnPush  // TOUJOURS OnPush
})
// standalone: true est le défaut depuis Angular 19 — ne pas le spécifier
export class QuestionFormComponent {
  // A. Injections (inject() fonction, pas le constructeur)
  private readonly gs  = inject(GameStateService);
  private readonly ws  = inject(WebSocketService);
  private readonly router = inject(Router);

  // B. Signal Inputs (remplacent @Input depuis Angular 21)
  readonly questionId = input.required<string>();

  // C. Signal Outputs (remplacent @Output + EventEmitter)
  readonly saved = output<void>();

  // D. Signals et computed locaux
  protected readonly isLoading = signal(false);
  protected readonly form = signal<QuestionForm>(EMPTY_FORM);

  // E. Méthodes publiques (handlers UI)
  onSubmit(): void { }

  // F. Méthodes privées
  private buildPayload(): CreateQuestionDto { }
}
```

**Règles strictes :**

- `ChangeDetectionStrategy.OnPush` sur tous les composants sans exception
- `inject()` plutôt que constructeur pour l'injection de dépendances
- Pas de logique dans le template — les conditions complexes vont dans des `computed`
- Les composants ne consomment jamais `HttpClient` directement — ils passent par leur service dédié
- Les composants n'importent jamais `environment` directement — ils passent par leur service dédié
- Template **toujours** dans un fichier `.component.html` dédié (`templateUrl`, jamais `template:`)
- Styles **toujours** dans un fichier `.component.css` dédié (`styleUrl`, jamais `styles:`)
- Notifications toast via `ToastService` injecté (jamais de signal `toastMessage` local)

---

## 🔧 Structure d'un service

```typescript
@Injectable({ providedIn: 'root' })  // root par défaut, scope plus fin si justifié
export class QuestionService {
  private readonly http = inject(HttpClient);
  private readonly env  = environment;

  // Méthodes retournant des Observables pour les appels HTTP
  getAll(filters: QuestionFilters): Observable<PagedResponse<Question>> {
    return this.http.get<PagedResponse<Question>>(
      `${this.env.serverUrl}/api/v1/questions`,
      { params: this.buildParams(filters) }
    );
  }

  create(dto: CreateQuestionDto): Observable<Question> {
    return this.http.post<Question>(`${this.env.serverUrl}/api/v1/questions`, dto);
  }

  // Méthodes retournant des Promises pour les appels one-shot (formulaires)
  async createAsync(dto: CreateQuestionDto): Promise<Question> {
    return firstValueFrom(this.create(dto));
  }

  private buildParams(filters: QuestionFilters): HttpParams { ... }
}
```

**Règle Observable vs Promise :**

| Cas | Retourner |
|---|---|
| Flux continu (WebSocket, polling) | `Observable` |
| Appel HTTP déclenché par un événement UI (submit, click) | `Promise` via `firstValueFrom` |
| Appel HTTP en réaction à un signal (liste avec filtres) | `Observable` |

---

## 🗂️ Organisation des imports TypeScript

Ordre imposé par ESLint (trois groupes séparés par une ligne vide) :

```typescript
// 1. Angular et RxJS
import { Component, inject, signal, computed } from '@angular/core';
import { Router } from '@angular/router';
import { Observable, firstValueFrom } from 'rxjs';

// 2. Projet — services et guards
import { GameStateService } from '../../core/services/game-state.service';
import { QuestionService  } from '../question.service';

// 3. Projet — modèles et constantes
import type { Question, QuestionFilters } from '../../core/models/question.models';
```

`import type` pour les imports purement typés — réduit le bundle à zero.

---

## 🧪 Tests

### Couverture minimale

| Cible | Couverture minimale |
|---|---|
| Services Core (`auth`, `websocket`, `game-state`) | ≥ 90 % |
| Guards | 100 % (peu de lignes, critiques) |
| Intercepteur | 100 % |
| Services de domaine (`question`, `quiz`, `game`) | ≥ 80 % |
| Composants | ≥ 70 % (test comportement, pas implémentation) |

### Règles générales

- **Un fichier `*.spec.ts` par fichier source** — jamais de fichier de test couvrant plusieurs sources
- **Arrange / Act / Assert** — structure systématique dans chaque `it()`
- **Pas de test du template HTML** — on teste le comportement observable (signals, Outputs, appels de service), pas la structure DOM
- Les tests de service utilisent `TestBed` minimal — pas de `AppModule`, pas de composants inutiles

### Structure type — test de service

```typescript
// game-state.service.spec.ts
describe('GameStateService', () => {
  let service: GameStateService;
  let wsMock: jest.Mocked<WebSocketService>;

  beforeEach(() => {
    wsMock = { messages$: NEVER, send: jest.fn() } as any;

    TestBed.configureTestingModule({
      providers: [
        GameStateService,
        { provide: WebSocketService, useValue: wsMock }
      ]
    });
    service = TestBed.inject(GameStateService);
  });

  describe('dispatch — question_title', () => {
    it('passe le statut à QUESTION_TITLE et stocke le titre', () => {
      // Arrange
      const msg: QuestionTitleMessage = {
        type: 'question_title',
        question_index: 3,
        question_type: 'MCQ',
        title: 'Quelle est la capitale de la France ?',
        time_limit: 30
      };

      // Act
      (wsMock.messages$ as any) = of(msg);
      TestBed.inject(GameStateService); // re-crée avec le flux mocké

      // Assert
      expect(service.status()).toBe('QUESTION_TITLE');
      expect(service.state().questionTitle)
        .toBe('Quelle est la capitale de la France ?');
    });
  });
});
```

### Structure type — test de composant

```typescript
// question-form.component.spec.ts
describe('QuestionFormComponent — création MCQ', () => {
  it('appelle questionService.create avec le bon payload à la soumission', async () => {
    // Arrange
    const questionService = { createAsync: jest.fn().mockResolvedValue({ id: '123' }) };

    const { getByLabelText, getByRole } = await render(QuestionFormComponent, {
      providers: [{ provide: QuestionService, useValue: questionService }]
    });

    // Act
    await userEvent.type(getByLabelText('Titre'), 'Quelle est la capitale ?');
    await userEvent.click(getByRole('button', { name: 'Créer la question' }));

    // Assert
    expect(questionService.createAsync).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'Quelle est la capitale ?' })
    );
  });
});
```

### Ce qu'on ne teste pas

- Les templates HTML (snapshot tests interdits — trop fragiles)
- La logique interne de Angular (routing, injection) — on teste nos propres comportements
- Les détails d'implémentation — on teste les contrats observables (ce que le service expose)

---

## 🚫 Anti-patterns interdits

| Anti-pattern | Alternative |
|---|---|
| `NgModule` | Standalone components (défaut depuis Angular 19) |
| `standalone: true` explicite | Ne pas spécifier — c'est le défaut |
| `@Input()` / `@Output()` décorateurs | `input()` / `input.required()` / `output()` signal-based |
| `EventEmitter` | `output()` depuis `@angular/core` |
| `APP_INITIALIZER` | `provideAppInitializer()` |
| `provideAnimations()` | `provideAnimationsAsync()` |
| `BehaviorSubject` public mutable | `signal` + méthode de mutation dédiée |
| `any` dans les types | Types stricts ou `unknown` + narrowing |
| Logique métier dans le template | `computed` dans le composant |
| `HttpClient` dans un composant | Service dédié (`HealthService`, `GameService`, etc.) |
| `import { environment }` dans un composant | Accès via le service dédié (ex: `QuestionService.getMediaUrl()`) |
| `template:` inline dans le composant | `templateUrl: './name.component.html'` — fichier dédié |
| `styles: [...]` inline dans le composant | `styleUrl: './name.component.css'` — fichier dédié |
| Signal `toastMessage` local + `showToast()` | `ToastService.show()` injecté — centralise les notifications |
| `subscribe()` sans `takeUntilDestroyed()` | `takeUntilDestroyed(this.destroyRef)` sur tous les `subscribe` |
| `console.log` en prod | Logger service (ou suppression par le build) |
| Mutation directe d'un objet de signal | `signal.update(s => ({ ...s, change }))` |
| Plusieurs responsabilités dans un composant | Découper en sous-composants ou services |
| Hardcoder l'URL du serveur | `environment.serverUrl` |
| `HttpClientTestingModule` | `provideHttpClient()` + `provideHttpClientTesting()` |

---

## 📝 Rappel dans chaque US Angular

Les US Angular référenceront ce document ainsi :

> Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack, les principes KISS/DRY/YAGNI/SOLID, la couverture des tests et les conventions de code.

---

**Dernière mise à jour** : 2026-03-30
