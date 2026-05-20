import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../constants/Colors';
import { Menu, User } from 'lucide-react-native';

interface HeaderNavProps {
    onProfilePress?: () => void;
    onMenuPress?: () => void;
}

export const HeaderNav = ({
    onProfilePress,
    onMenuPress,
}: HeaderNavProps) => {
    const insets = useSafeAreaInsets();

    return (
        <View style={[
            styles.container,
            { paddingTop: insets.top + 8 }
        ]}>
            {/* Left: Hamburger Menu */}
            <TouchableOpacity
                style={styles.iconButton}
                onPress={onMenuPress}
                activeOpacity={0.7}
            >
                <Menu color={Colors.dark.text} size={22} />
            </TouchableOpacity>

            {/* Right: User Profile */}
            <TouchableOpacity
                style={styles.iconButton}
                onPress={onProfilePress}
                activeOpacity={0.7}
            >
                <User color={Colors.dark.text} size={22} />
            </TouchableOpacity>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingHorizontal: 16,
        paddingBottom: 8,
        width: '100%',
        position: 'absolute',
        top: 0,
        zIndex: 10,
    },
    iconButton: {
        width: 42,
        height: 42,
        borderRadius: 12,
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.12)',
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: 'rgba(30,30,35,0.85)',
    },
});
