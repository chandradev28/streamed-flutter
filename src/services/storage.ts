// Storage service for persisting user settings
import AsyncStorage from '@react-native-async-storage/async-storage';

const STORAGE_KEYS = {
    TORBOX_API_KEY: '@streamed_torbox_api_key',
    DNS_PROVIDER: '@streamed_dns_provider',
    ACTIVE_INDEXER: '@streamed_active_indexer',
    ZILEAN_ENABLED: '@streamed_zilean_enabled',     // Zilean alongside other sources
    ZILEAN_DMM_MODE: '@streamed_zilean_dmm_mode',   // Exclusive Zilean mode
};

export type DnsProviderType = 'none' | 'cloudflare' | 'google' | 'adguard' | 'quad9';
export type IndexerType = 'torrentio' | 'zilean';

export const StorageService = {
    // TorBox API Key
    async getTorBoxApiKey(): Promise<string | null> {
        try {
            return await AsyncStorage.getItem(STORAGE_KEYS.TORBOX_API_KEY);
        } catch (error) {
            console.error('Error getting TorBox API key:', error);
            return null;
        }
    },

    async setTorBoxApiKey(apiKey: string): Promise<boolean> {
        try {
            await AsyncStorage.setItem(STORAGE_KEYS.TORBOX_API_KEY, apiKey);
            return true;
        } catch (error) {
            console.error('Error saving TorBox API key:', error);
            return false;
        }
    },

    async removeTorBoxApiKey(): Promise<boolean> {
        try {
            await AsyncStorage.removeItem(STORAGE_KEYS.TORBOX_API_KEY);
            return true;
        } catch (error) {
            console.error('Error removing TorBox API key:', error);
            return false;
        }
    },

    // Check if TorBox is configured
    async isTorBoxConfigured(): Promise<boolean> {
        const apiKey = await this.getTorBoxApiKey();
        return !!apiKey && apiKey.length > 0;
    },

    // DNS Provider
    async getDnsProvider(): Promise<DnsProviderType> {
        try {
            const provider = await AsyncStorage.getItem(STORAGE_KEYS.DNS_PROVIDER);
            return (provider as DnsProviderType) || 'none';
        } catch (error) {
            console.error('Error getting DNS provider:', error);
            return 'none';
        }
    },

    async setDnsProvider(provider: DnsProviderType): Promise<boolean> {
        try {
            await AsyncStorage.setItem(STORAGE_KEYS.DNS_PROVIDER, provider);
            return true;
        } catch (error) {
            console.error('Error saving DNS provider:', error);
            return false;
        }
    },

    // Active Indexer (for TorBox)
    async getActiveIndexer(): Promise<IndexerType> {
        try {
            const indexer = await AsyncStorage.getItem(STORAGE_KEYS.ACTIVE_INDEXER);
            return (indexer as IndexerType) || 'torrentio';
        } catch (error) {
            console.error('Error getting active indexer:', error);
            return 'torrentio';
        }
    },

    async setActiveIndexer(indexer: IndexerType): Promise<boolean> {
        try {
            await AsyncStorage.setItem(STORAGE_KEYS.ACTIVE_INDEXER, indexer);
            return true;
        } catch (error) {
            console.error('Error saving active indexer:', error);
            return false;
        }
    },

    // Zilean Settings
    async getZileanEnabled(): Promise<boolean> {
        try {
            const value = await AsyncStorage.getItem(STORAGE_KEYS.ZILEAN_ENABLED);
            return value === 'true';
        } catch (error) {
            console.error('Error getting Zilean enabled:', error);
            return false;
        }
    },

    async setZileanEnabled(enabled: boolean): Promise<boolean> {
        try {
            await AsyncStorage.setItem(STORAGE_KEYS.ZILEAN_ENABLED, enabled.toString());
            return true;
        } catch (error) {
            console.error('Error saving Zilean enabled:', error);
            return false;
        }
    },

    // Zilean DMM Mode (exclusive mode - only Zilean results)
    async getZileanDmmMode(): Promise<boolean> {
        try {
            const value = await AsyncStorage.getItem(STORAGE_KEYS.ZILEAN_DMM_MODE);
            return value === 'true';
        } catch (error) {
            console.error('Error getting Zilean DMM mode:', error);
            return false;
        }
    },

    async setZileanDmmMode(enabled: boolean): Promise<boolean> {
        try {
            await AsyncStorage.setItem(STORAGE_KEYS.ZILEAN_DMM_MODE, enabled.toString());
            return true;
        } catch (error) {
            console.error('Error saving Zilean DMM mode:', error);
            return false;
        }
    },

    // ============================================================================
    // DOWNLOAD BOOKMARKS - Save torrents per movie/show for quick access
    // ============================================================================

    /**
     * Get download bookmarks for a specific movie or TV show
     */
    async getDownloadsForMedia(mediaType: 'movie' | 'tv', mediaId: number): Promise<DownloadBookmark[]> {
        try {
            const key = `@streamed_downloads_${mediaType}_${mediaId}`;
            const data = await AsyncStorage.getItem(key);
            if (!data) return [];
            return JSON.parse(data) as DownloadBookmark[];
        } catch (error) {
            console.error('Error getting downloads for media:', error);
            return [];
        }
    },

    /**
     * Add a torrent bookmark to a movie/show
     */
    async addDownloadBookmark(
        mediaType: 'movie' | 'tv',
        mediaId: number,
        bookmark: DownloadBookmark
    ): Promise<boolean> {
        try {
            const key = `@streamed_downloads_${mediaType}_${mediaId}`;
            const existing = await this.getDownloadsForMedia(mediaType, mediaId);

            // Check if already exists (by torrentId or hash)
            const exists = existing.some(
                b => b.torrentId === bookmark.torrentId || b.torrentHash === bookmark.torrentHash
            );

            if (!exists) {
                existing.push(bookmark);
                await AsyncStorage.setItem(key, JSON.stringify(existing));
            }
            return true;
        } catch (error) {
            console.error('Error adding download bookmark:', error);
            return false;
        }
    },

    /**
     * Remove a torrent bookmark (does NOT delete from TorBox)
     */
    async removeDownloadBookmark(
        mediaType: 'movie' | 'tv',
        mediaId: number,
        torrentId: number
    ): Promise<boolean> {
        try {
            const key = `@streamed_downloads_${mediaType}_${mediaId}`;
            const existing = await this.getDownloadsForMedia(mediaType, mediaId);
            const filtered = existing.filter(b => b.torrentId !== torrentId);
            await AsyncStorage.setItem(key, JSON.stringify(filtered));
            return true;
        } catch (error) {
            console.error('Error removing download bookmark:', error);
            return false;
        }
    },

    /**
     * Clear all download bookmarks for a movie/show
     */
    async clearDownloadsForMedia(mediaType: 'movie' | 'tv', mediaId: number): Promise<boolean> {
        try {
            const key = `@streamed_downloads_${mediaType}_${mediaId}`;
            await AsyncStorage.removeItem(key);
            return true;
        } catch (error) {
            console.error('Error clearing downloads:', error);
            return false;
        }
    },

};

// Download bookmark type
export interface DownloadBookmark {
    torrentId: number;
    torrentHash: string;
    torrentName: string;
    size: number;
    quality?: string;
    addedAt: number;
    // For TV shows
    seasonNumber?: number;
    episodeNumber?: number;
}
