import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Colors } from '../constants/Colors';
import { TorboxersSection } from '../components/TorboxersSection';

export const TorBoxersScreen = () => {
    const navigation = useNavigation<any>();

    const handleNavigate = (screen: string) => {
        navigation.navigate(screen);
    };

    const handleGoToStreamed = () => {
        navigation.goBack();
    };

    return (
        <View style={styles.container}>
            <TorboxersSection
                onNavigate={handleNavigate}
                onGoToStreamed={handleGoToStreamed}
            />
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: Colors.dark.background,
    },
});
