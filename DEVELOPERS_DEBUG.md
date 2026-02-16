# Roamly - Developer Debug Guide

## Overview
Roamly is a travel companion app that allows users to discover and share travel spots. This document contains important development information, testing credentials, and debugging tips.

---

## Latest Updates (Feb 2026)

### ✨ Authentication System Overhaul
- **Login-first flow**: App now opens to login/signup screen instead of directly to map
- **Tabbed interface**: Login and Sign Up tabs for easy switching
- **Extended signup**: Collects full name, email, phone number, password, and confirmation
- **Firestore integration**: User profiles stored in `users` collection with name and phone

### ✨ Map Picker for Users & Admins
- **User spot creation**: Choice dialog when adding spots
  - "Current Location" - Uses GPS
  - "Pick on Map" - Opens interactive map to select any location globally
- **Admin spot creation**: Same map picker functionality
- **No restrictions**: Removed 2km radius limitation - spots can be added anywhere

### 🗂️ Data Models

#### UserProfile (Firestore: `users/{uid}`)
```dart
{
  uid: String,           // Firebase Auth UID
  email: String,         // User email
  name: String,          // Full name
  phoneNumber: String,   // Phone number (min 10 digits)
  createdAt: Timestamp   // Account creation
}
```

#### LocationModel (Firestore: `locations` collection)
```dart
{
  id: String,
  name: String,
  latitude: double,
  longitude: double,
  description: String?,
  imageUrl: String?,
  rating: double,
  type: LocationType,    // generated, favorite, scenic, visited
  status: String,        // 'pending' or 'approved'
  createdAt: Timestamp
}
```

#### Firestore Indexes
The "Find Companion" feature requires a composite index for searching:
- **Collection**: `users`
- **Fields**: `isDiscoverable` (Ascending), `name` (Ascending)
- **Status**: Required for `searchUsers` query to filter by discoverability and sort by name simultaneously.
- **Creation**: Click the link provided in the debug console error or create manually in Firebase Console.

---

## Testing Credentials

### Admin Account
- **Email**: `admin@roamly.com`
- **Password**: (Set in Firebase Console)
- **Access**: Admin Dashboard with pending spot approvals

### Test User Accounts
Create test accounts via the Sign Up tab with:
- Full name
- Email
- Phone number (10+ digits)
- Password (6+ characters)

---

## Quick Testing Guide

### 1. Signup Flow
```
Open app → Splash (3s) → Login/Signup
Tap "Sign Up" tab
Fill: Name, Email, Phone, Password, Confirm
→ Creates Firebase Auth account
→ Saves profile to Firestore users/{uid}
→ Navigates to User Dashboard
```

### 2. User Add Spot with Map Picker
```
Login as user
Tap + FAB
Choose "Pick on Map"
→ Interactive map opens
Tap anywhere on map
Tap "Select This Location"
Fill spot details
→ Spot created with status: 'pending'
```

### 3. Admin Spot Management
```
Login as admin@roamly.com
→ Admin Dashboard shows pending spots
Tap "Approve" or "Reject"
Tap "Add New Spot" FAB
→ Map picker opens
Select location globally
Fill details
→ Spot created with status: 'approved'
```

---

## Important Files

### Authentication
- `lib/features/auth/screens/splash_screen.dart` - Navigates to login
- `lib/features/auth/screens/login_screen.dart` - Tabbed login/signup with profile creation
- `lib/models/user_profile_model.dart` - User profile data model

### Core Services
- `lib/core/services/location_service.dart` - Location CRUD, removed 2km restriction
  - `addLocation()` - User spots → pending
  - `addLocationAsAdmin()` - Admin spots → approved
  - `getPendingLocations()` - For admin approval queue

### Shared Widgets
- `lib/features/shared/widgets/spot_map_picker.dart` - Interactive map picker (used by both user & admin)

### Screens
- `lib/features/home/screens/home_screen.dart` - User dashboard with map, location choice dialog
- `lib/features/admin/screens/admin_dashboard.dart` - Admin dashboard with approval queue

### Routing
- `lib/main.dart` - Routes: `/` (splash), `/login`, `/home`, `/admin`

---

## Firebase Configuration

### Collections Used
1. **users** - User profiles
   - Document ID: Firebase Auth UID
   - Fields: uid, email, name, phoneNumber, createdAt

2. **locations** - All spots
   - Auto-generated IDs
   - Fields: name, latitude, longitude, description, imageUrl, rating, type, status, createdAt

### Security Rules Required
```javascript
// users collection
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;
}

// locations collection
match /locations/{locationId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update: if request.auth.token.email == 'admin@roamly.com';
  allow delete: if request.auth.token.email == 'admin@roamly.com';
}
```

---

## Common Debug Scenarios

### Issue: Signup doesn't navigate
**Check:**
- Firestore has write permissions for `users` collection
- User profile data is being saved (check Firestore console)
- No errors in debug console

### Issue: Map picker doesn't open
**Check:**
- Route to `SpotMapPicker` widget is correct
- Import path: `lib/features/shared/widgets/spot_map_picker.dart`

### Issue: Spots not appearing on map
**Check:**
- Spot status is 'approved' (user spots need admin approval)
- `getLocations()` in LocationService filters by status: 'approved'
- Map is centered on correct coordinates

### Issue: Admin can't see pending spots
**Check:**
- User spots have status: 'pending'
- `getPendingLocations()` filters correctly
- Admin is logged in with `admin@roamly.com`

### Issue: Location choice dialog not appearing
**Check:**
- `_handleAddSpot()` in home_screen.dart shows dialog
- Both navigation options return correct values

---

## Development Commands

```bash
# Run on Chrome
flutter run -d chrome

# Run on specific device
flutter run -d linux

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get

# Build for web
flutter build web
```

---

## Architecture Notes

### Null Safety
- All nullable types properly handled with `?` and `!` operators
- Flow analysis assisted with local variables after null checks

### State Management
- StatefulWidget with setState for local UI state
- Firebase Auth for authentication state
- Firestore for persistent data

### Navigation Flow
```
Splash (3s delay)
  ↓
Login/Signup (Tabs)
  ↓
Role Check (email-based)
  ├─ admin@roamly.com → Admin Dashboard
  └─ other users → User Dashboard (HomeScreen)
```

---

## Known Issues & Limitations

1. **OSM Tile Servers**: Using OpenStreetMap public tiles (see console warnings)
   - For production, consider paid tile provider
   - See: https://docs.fleaflet.dev/osm-warn

2. **Email-based Admin**: Admin role determined by email hardcode
   - Future: Use Firebase Custom Claims for role management

3. **No offline support**: Requires internet for Firebase and map tiles

4. **Web geolocation**: May not work on all browsers/contexts
   - Always provide map picker as fallback

---

## Testing Checklist

- [ ] New user signup with all fields
- [ ] User login with existing account
- [ ] Admin login with admin@roamly.com
- [ ] User add spot - current location
- [ ] User add spot - map picker
- [ ] Admin approve pending spot
- [ ] Admin reject pending spot
- [ ] Admin add spot with map picker
- [ ] Logout from user dashboard
- [ ] Logout from admin dashboard
- [ ] User profile saved to Firestore
- [ ] Spot status workflow (pending → approved)

---

## Debug Console Messages

### Expected Messages
```
SIGNUP SUCCESS: [email]
LOGIN SUCCESS: [email] (Admin: [true/false])
```

### Map Warnings (Normal)
```
flutter_map wants to help keep map data available for everyone...
OSM Tile Usage Policy warning
```

---

## Contact & Support

For issues or questions:
1. Check Firestore console for data integrity
2. Review Firebase Authentication users list
3. Check debug console for error messages
4. Verify all imports and routing paths

Last Updated: February 2026
