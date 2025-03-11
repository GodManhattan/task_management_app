# Detailed Development Roadmap for Task Management App

## Phase 1: Setup & Foundation (Week 1)

### Days 1-2: Project Setup
- **Create Flutter project**
  - Run `flutter create task_manager_app --org com.yourname`
  - Set up folder structure: `/lib/data`, `/lib/domain`, `/lib/presentation`, `/lib/core`
- **Configure dependencies**
  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    supabase_flutter: ^1.10.25
    flutter_bloc: ^8.1.3
    bloc: ^8.1.2
    equatable: ^2.0.5
    go_router: ^12.1.1
    flutter_secure_storage: ^9.0.0
    intl: ^0.18.1
    cached_network_image: ^3.3.0
    flutter_svg: ^2.0.9
    uuid: ^4.2.1
  
  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^3.0.1
    bloc_test: ^9.1.4
    mockito: ^5.4.2
  ```
- **Set up Supabase project**
  - Create account on supabase.com 
  
  database password QzseXWiCnRS2HvXB
  Project URL
https://chwswwssmegejiknagqz.supabase.co

API Key
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNod3N3d3NzbWVnZWppa25hZ3F6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1NTAyOTQsImV4cCI6MjA1NzEyNjI5NH0.SByMYeavX2FLcseCL9xWv8nZkdKednpsYnEYrNVqI00


const supabaseUrl = 'https://chwswwssmegejiknagqz.supabase.co';
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(MyApp());
}

  - Create new project
  - Save API URL and public anon key
  - Create database tables:
    ```sql
    -- Users table (managed by Supabase Auth)
    create table public.profiles (
      id uuid references auth.users on delete cascade,
      email text not null,
      full_name text,
      avatar_url text,
      created_at timestamptz default now(),
      primary key (id)
    );

    -- Tasks table
    create table public.tasks (
      id uuid default uuid_generate_v4() primary key,
      title text not null,
      description text,
      status text not null default 'pending',
      priority text not null default 'medium',
      due_date timestamptz,
      created_at timestamptz default now(),
      updated_at timestamptz default now(),
      owner_id uuid references auth.users not null,
      assignee_id uuid references auth.users
    );

    -- Comments table
    create table public.comments (
      id uuid default uuid_generate_v4() primary key,
      task_id uuid references public.tasks on delete cascade not null,
      user_id uuid references auth.users not null,
      content text not null,
      created_at timestamptz default now()
    );
    ```
- **Configure Row Level Security**
  - Create policies for each table

### Days 3-5: Core Architecture
- **Create core models**
  - Task model with fromJson/toJson
  - User model with fromJson/toJson
  - Comment model with fromJson/toJson
- **Set up BLoC architecture**
  - Create base state classes (initial, loading, success, error)
  - Set up repository interfaces
  - Create Supabase repository implementations
- **Implement dependency injection**
  - Set up service locator using get_it
  - Register repositories and services
- **Configure routing**
  - Set up GoRouter with initial routes
  - Create navigation helpers
- **Theme implementation**
  - Define color scheme
  - Custom text styles
  - Custom widgets for buttons, cards, inputs

## Phase 2: Authentication & Basic Features (Week 2)

### Days 1-3: Authentication
- **Supabase auth implementation**
  - Create AuthRepository class
  - Implement sign up, login, logout methods
  - Set up password reset flow
- **Auth screens**
  - Login screen with email/password
  - Registration screen
  - Password reset screen
  - Email verification handling
- **Auth Cubit**
  - Create states: AuthInitial, AuthLoading, Authenticated, Unauthenticated, AuthError
  - Implement login, register, logout methods
  - Handle authentication persistence
- **User profile**
  - Profile screen UI
  - Edit profile functionality
  - Avatar upload and management

### Days 4-7: Core Task Management
- **TaskRepository implementation**
  - CRUD operations for tasks
  - Filtering methods
  - Supabase integration
- **Task Cubit**
  - Create states for task operations
  - Implement load, create, update, delete methods
- **Task list UI**
  - Create ListView with task cards
  - Implement pull-to-refresh
  - Add loading states
  - Empty state design
- **Task creation**
  - Form with validation
  - Date picker for due dates
  - Priority selection
  - Assignee selection
- **Task details**
  - Detailed view with all task information
  - Status change buttons
  - Edit/delete options
  - Comments section
- **Comments implementation**
  - Comment Cubit
  - Add comment UI
  - Comment list with user information

## Phase 3: Real-time & Advanced Features (Week 3)

### Days 1-3: Real-time Features
- **Supabase real-time setup**
  - Configure subscriptions for tasks table
  - Set up channel for comments
- **Real-time task updates**
  - Update task list when changes occur
  - Show notifications for task changes
  - Handle conflicts
- **Real-time comments**
  - Live comment updates
  - Comment count badges
  - Typing indicators
- **Activity tracking**
  - Record status changes
  - Track assignments
  - Create activity feed

### Days 4-7: Additional Features
- **Filtering system**
  - Filter by status, priority, assignee
  - Search functionality
  - Sort options (due date, creation date)
- **Due date handling**
  - Calendar view option
  - Overdue task highlighting
  - Due date reminders
- **Team management**
  - User list view
  - Assign tasks to team members
  - User availability status
- **Status workflow**
  - Custom status progression
  - Status change validation
  - Status history tracking

## Phase 4: AI Integration (Week 4)

### Days 1-2: AI Service Layer
- **Local AI setup**
  - Install Ollama locally
  - Pull models (e.g., mistral, codellama)
  - Create test environment
- **AI service class**
  ```dart
  class AIService {
    final String _baseUrl;
    final http.Client _client;
    
    AIService({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? 'http://localhost:11434/api',
        _client = client ?? http.Client();
        
    Future<String> generateResponse(String prompt) async {
      // Implementation
    }
    
    Future<Map<String, dynamic>> analyzeTask(String title, String description) async {
      // Implementation
    }
  }
  ```
- **Prompt templates**
  - Create template for task analysis
  - Build template for summarization
  - Design template for prioritization

### Days 3-5: AI Feature Implementation
- **Task prioritization**
  - Analyze task content to suggest priority
  - Consider due dates and team workload
  - Implement UI for suggestions
- **Auto-categorization**
  - Extract keywords from task descriptions
  - Suggest tags or categories
  - Allow user confirmation
- **Writing assistance**
  - Improve task descriptions
  - Grammar and clarity suggestions
  - Completion suggestions
- **AI Assistant UI**
  - Assistant button or panel
  - Suggestion cards
  - Acceptance/rejection mechanism
  - Feedback collection

### Days 6-7: Testing & Refinement
- **Prompt optimization**
  - Test with various task types
  - Refine prompts for better results
  - Add context to improve relevance
- **Caching system**
  - Store common responses
  - Implement LRU cache
  - Cache invalidation strategy
- **Fallback mechanisms**
  - Handle API failures
  - Provide offline suggestions
  - Graceful degradation

## Phase 5: Polishing & MVP Launch (Week 5)

### Days 1-3: UI/UX Refinement
- **Responsive design**
  - Test on different screen sizes
  - Implement adaptive layouts
  - Desktop/tablet optimizations
- **Animations**
  - Task list item animations
  - Page transitions
  - Loading indicators
- **Error handling**
  - User-friendly error messages
  - Retry mechanisms
  - Offline indicators
- **Accessibility**
  - Semantic labels
  - Contrast checking
  - Screen reader compatibility

### Days 4-5: Testing
- **Unit tests**
  - Test repositories
  - Test BLoCs/Cubits
  - Test AI service
- **Widget tests**
  - Test key UI components
  - Form validation tests
  - Navigation tests
- **Performance optimization**
  - Memory usage analysis
  - Render optimization
  - Network call optimization
- **Cross-platform testing**
  - Test on iOS and Android
  - Test on web (if targeting)

### Days 6-7: Deployment Preparation
- **App signing**
  - Generate keystore for Android
  - Set up certificates for iOS
- **Documentation**
  - Create README
  - Document API endpoints
  - Create user guide
- **Beta testing setup**
  - Configure Firebase App Distribution
  - Or set up TestFlight for iOS
  - Create feedback collection form
- **Onboarding flow**
  - First-time user experience
  - Tutorial screens
  - Sample data creation
