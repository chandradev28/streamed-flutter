import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { HomeScreen } from './src/screens/HomeScreen';
import { MovieDetailScreen } from './src/screens/MovieDetailScreen';
import { EpisodeScreen } from './src/screens/EpisodeScreen';
import { VideoPlayerScreen } from './src/screens/VideoPlayerScreen';
import { IndexerStatusScreen } from './src/screens/IndexerStatusScreen';
import { AddonsScreen } from './src/screens/AddonsScreen';
import { MagnetScreen } from './src/screens/MagnetScreen';
import { ComingSoonScreen } from './src/screens/ComingSoonScreen';
import { TorBoxersScreen } from './src/screens/TorBoxersScreen';

const Stack = createNativeStackNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <StatusBar style="light" />
      <Stack.Navigator screenOptions={{ headerShown: false, animation: 'fade' }}>
        <Stack.Screen name="Home" component={HomeScreen} />
        <Stack.Screen name="MovieDetail" component={MovieDetailScreen} options={{ animation: 'slide_from_bottom' }} />
        <Stack.Screen name="Episodes" component={EpisodeScreen} options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="VideoPlayer" component={VideoPlayerScreen} options={{ animation: 'fade', presentation: 'fullScreenModal' }} />
        <Stack.Screen name="IndexerStatus" component={IndexerStatusScreen} options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="Addons" component={AddonsScreen} options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="Magnet" component={MagnetScreen} options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="ComingSoon" component={ComingSoonScreen} options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="TorBoxers" component={TorBoxersScreen} options={{ animation: 'slide_from_right' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
