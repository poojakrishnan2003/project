import 'package:flutter/material.dart';
import 'package:roamly/core/services/request_service.dart';
import 'package:roamly/core/services/user_service.dart';
import 'package:roamly/models/companion_request_model.dart';
import 'package:roamly/models/user_profile_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:roamly/core/constants/mapbox_config.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final RequestService _requestService = RequestService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Companion Requests'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Incoming'),
              Tab(text: 'Connected'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildIncomingRequests(), _buildConnectedUsers()],
        ),
      ),
    );
  }

  Widget _buildIncomingRequests() {
    return StreamBuilder<List<CompanionRequest>>(
      stream: _requestService.getIncomingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('No incoming requests'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(request.senderName),
                subtitle: Text(
                  'Sent on ${request.timestamp.toLocal().toString().split(' ')[0]}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () async {
                        await _requestService.acceptRequest(request);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request Accepted')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () async {
                        await _requestService.rejectRequest(request.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request Rejected')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConnectedUsers() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please log in to view connections'));
    }

    return StreamBuilder<UserProfile?>(
      stream: _userService.getUserStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userProfile = snapshot.data;
        if (userProfile == null || userProfile.connectedUserIds.isEmpty) {
          return const Center(child: Text('No connected travelers yet'));
        }

        return FutureBuilder<List<UserProfile>>(
          future: _userService.getUsers(userProfile.connectedUserIds),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (userSnapshot.hasError) {
              return Center(child: Text('Error: ${userSnapshot.error}'));
            }

            final users = userSnapshot.data ?? [];
            if (users.isEmpty) {
              return const Center(child: Text('No connected travelers found'));
            }

            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.phoneNumber.isNotEmpty)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.phone),
                                title: Text(user.phoneNumber),
                              ),
                            const Divider(),
                            const Text(
                              'Current Location',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (user.location != null) ...[
                              Text(
                                'Lat: ${user.location!['latitude'].toStringAsFixed(4)}, '
                                'Lng: ${user.location!['longitude'].toStringAsFixed(4)}',
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 150,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      user.location!['latitude'],
                                      user.location!['longitude'],
                                    ),
                                    initialZoom: 13.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: MapboxConfig.streetStyleUrl,
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            user.location!['latitude'],
                                            user.location!['longitude'],
                                          ),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ] else
                              const Text('Location not available'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
