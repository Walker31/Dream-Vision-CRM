# DreamVision

A comprehensive Flutter-based CRM (Customer Relationship Management) application designed for educational institutions to manage student enquiries, follow-ups, and admission pipeline workflows efficiently.

## Overview

DreamVision is a multi-role CRM system that streamlines the student recruitment and admission process with features for enquiry management, follow-up tracking, lead scoring, and team collaboration across different user roles.

## Key Features

### 👥 Multi-Role Support
- **Telecaller**: Cold-call leads, manage daily pipelines, log follow-ups
- **Counsellor**: Conduct counseling sessions, manage assigned leads, track academic discussions
- **Manager**: Monitor team performance, review conversion metrics, manage telecaller assignments
- **Admin**: System administration, user management, configuration, reporting

### 📋 Enquiry Management
- Create and manage student enquiries with detailed information
  - Student personal details (name, DOB, phone number)
  - Parent contact information (father's phone, mother's phone, occupation)
  - Academic details (standard, board, exam preferences)
  - School affiliation and referral source
  - Lead temperature classification (Hot/Warm/Cold)
- Bulk import enquiries via Excel templates
- Soft delete functionality with is_active flag
- Search and filter by multiple criteria

### 📞 Follow-Up Tracking
- Log detailed follow-ups for each enquiry
- Track status changes before and after follow-ups
- Mark CNR (Could Not Reach) calls
- Schedule next follow-up dates
- Record academic details discussed
- Add remarks and notes for each interaction
- Full follow-up history with timestamps

### 📊 Dashboard & Analytics
- Status-wise lead count visualization
- Next follow-up schedule view
- Lead temperature distribution
- Conversion metrics by telecaller
- Real-time dashboard updates with caching optimization
- Performance charts and analytics

### 🎯 Lead Management
- Assign leads to specific telecallers
- Auto-assignment based on user role
- Lead status workflow (New → Interested → Counselled → Admitted)
- Admission confirmation tracking
- Fee negotiation recording (total fees, installments)

### 📱 User Experience
- iOS and Android native support
- Fast, responsive UI with Material Design
- Smooth navigation using GoRouter
- Real-time form validation
- Offline data caching with Redis integration
- Call integration for direct dialing
- File picker for document attachments

### 🔒 Security & Permissions
- Role-based access control
- User authentication and authorization
- Secure password management
- Audit trails with created_by/updated_by tracking
- Permission-based view restrictions

## Architecture

### Frontend (Flutter)
- **State Management**: Provider pattern
- **Navigation**: GoRouter for deep linking and type-safe routing
- **HTTP Client**: Dio for API communication
- **UI Framework**: Material Design 3
- **Data Models**: Type-safe models with JSON serialization
- **Services**: Abstracted API service layer

### Backend (Django REST Framework)
- **Database Models**: PostgreSQL
  - Enquiry model with comprehensive fields
  - FollowUp model with status tracking
  - EnquiryStatus, EnquirySource, School, Exam lookup tables
  - AcademicPerformance model for tracking student academics
- **API**: RESTful endpoints with filtering and pagination
- **Caching**: Redis caching for dashboard and list queries
- **Authentication**: Token-based authentication

## File Structure

```
dreamvision/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── splash_screen.dart        # Splash screen widget
│   ├── pages/                    # Different user role pages
│   │   ├── Admin/                # Admin dashboard and management
│   │   ├── Counsellor/           # Counsellor pages
│   │   ├── Telecaller/           # Telecaller dashboard
│   │   └── miscellaneous/        # Shared pages (follow-ups, etc.)
│   ├── models/                   # Data models (Enquiry, FollowUp, etc.)
│   ├── services/                 # API service layer
│   ├── providers/                # State management
│   ├── dialogs/                  # Dialog widgets
│   ├── widgets/                  # Reusable UI components
│   ├── utils/                    # Utility functions
│   └── config/                   # App configuration
├── assets/                       # Images, fonts, and static resources
└── pubspec.yaml                  # Flutter dependencies
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio or Xcode for mobile development
- Internet connection for backend API

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd dreamvision
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Build for Release

- **Android**
  ```bash
  flutter build apk --release
  ```

- **iOS**
  ```bash
  flutter build ios --release
  ```

## Configuration

Update API endpoints and configuration in:
- `lib/config/` - API base URLs and constants
- `lib/services/enquiry_service.dart` - Service configuration

## Environment Variables

Configure the following environment variables:
- `API_BASE_URL` - Backend API endpoint
- `API_TIMEOUT` - Request timeout duration

## Key Dependencies

- **UI & Navigation**: `flutter_speed_dial`, `go_router`, `flutter_expandable_fab`
- **State Management**: `provider`
- **HTTP Client**: `dio`
- **Utilities**: `intl`, `logger`, `url_launcher`
- **File Operations**: `file_picker`, `file_saver`, `path_provider`
- **Device Info**: `device_info_plus`, `connectivity_plus`
- **Storage**: `flutter_secure_storage`, `shared_preferences`
- **Native Plugins**: `permission_handler`, `flutter_plugin_android_lifecycle`

## Usage Guide

### For Telecallers
1. Login with your credentials
2. View assigned leads on the dashboard
3. Click on a lead to view details
4. Use the call button to directly dial the father's or student's number
5. Create follow-ups by logging call outcomes
6. Schedule next follow-up dates
7. Mark CNR if unable to reach

### For Counsellors
1. View counselling-assigned leads
2. Edit enquiry details after counselling session
3. Log academic details discussed
4. Create follow-ups with status changes
5. Confirm admissions when finalized

### For Managers
1. Monitor team performance metrics
2. View status-wise lead distribution
3. Analyze follow-up completion rates
4. Reassign leads as needed

### For Admins
1. Manage user accounts and roles
2. Configure lookup tables (statuses, sources, etc.)
3. Generate reports and analytics
4. Perform bulk operations
5. Manage system settings

## API Integration

The app communicates with a Django REST Framework backend. Key endpoints:

- `GET/POST /enquiries/` - List and create enquiries
- `GET/PATCH/DELETE /enquiries/{id}/` - Enquiry details and updates
- `GET/POST /follow-ups/` - Follow-up management
- `GET /enquiries/{id}/follow-ups/` - Enquiry-specific follow-ups

All requests use token-based authentication with headers:
```
Authorization: Token <auth-token>
```

## Performance Optimization

- **Caching**: Redis integration for frequently accessed data (dashboards, lists)
- **Pagination**: Large datasets are paginated (50 items per page by default)
- **Image Optimization**: Lazy loading and image caching
- **State Management**: Efficient state updates using Provider

## Troubleshooting

### Common Issues

1. **API Connection Errors**
   - Check backend server status
   - Verify API_BASE_URL configuration
   - Check network connectivity

2. **Authentication Failed**
   - Ensure valid credentials
   - Check token expiration
   - Clear app cache and re-login

3. **Slow Performance**
   - Clear app cache
   - Reduce pagination size if needed
   - Check Redis cache status on backend

## Support & Contribution

For bug reports, feature requests, or contributions, please contact the development team.

## Version History

- **v1.0.0** - Initial release with core features
  - Multi-role CRM functionality
  - Enquiry and follow-up management
  - Dashboard and analytics
  - Bulk upload support

## License

This project is proprietary software. All rights reserved.
 