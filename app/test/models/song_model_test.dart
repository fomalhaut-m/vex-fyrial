import 'package:flutter_test/flutter_test.dart';
import 'package:vexfy/data/models/song_model.dart';

void main() {
    group('SongModel 数据模型测试', () {
        test('fromMap 正确解析本地歌曲', () {
            final map = {
                'id': 'abc123',
                'title': '晴天',
                'artist': '周杰伦',
                'album': '叶惠美',
                'duration': 269000,
                'source': 'local',
                'file_path': '/music/qingtian.mp3',
                'is_favorite': 1,
                'play_count': 5,
            };

            final song = SongModel.fromMap(map);

            expect(song.id, 'abc123');
            expect(song.title, '晴天');
            expect(song.artist, '周杰伦');
            expect(song.album, '叶惠美');
            expect(song.duration, 269000);
            expect(song.source, SongSource.local);
            expect(song.isLocal, true);
            expect(song.isFavorite, true);
            expect(song.playCount, 5);
        });

        test('fromMap 正确解析在线歌曲', () {
            final map = {
                'id': 'xyz789',
                'title': '七里香',
                'artist': '周杰伦',
                'album': '七里香',
                'duration': 294000,
                'source': 'online',
                'online_url': 'https://music.example.com/7lx.mp3',
                'is_favorite': 0,
                'play_count': 0,
            };

            final song = SongModel.fromMap(map);

            expect(song.id, 'xyz789');
            expect(song.title, '七里香');
            expect(song.source, SongSource.online);
            expect(song.isLocal, false);
            expect(song.onlineUrl, 'https://music.example.com/7lx.mp3');
        });

        test('toMap 正确序列化为数据库格式', () {
            final song = SongModel(
                id: 'abc123',
                title: '七里香',
                artist: '周杰伦',
                album: '七里香',
                duration: 294000,
                source: SongSource.local,
                filePath: '/music/qili Xiang.mp3',
                isFavorite: false,
            );

            final map = song.toMap();

            expect(map['id'], 'abc123');
            expect(map['title'], '七里香');
            expect(map['source'], 'local');
            expect(map['is_favorite'], 0); // false → 0
            expect(map['file_path'], '/music/qili Xiang.mp3');
        });

        test('toMap 在线歌曲 source 为 online', () {
            final song = SongModel(
                id: 'xyz789',
                title: '测试',
                artist: '测试',
                duration: 180000,
                source: SongSource.online,
                onlineUrl: 'https://example.com/test.mp3',
            );

            final map = song.toMap();

            expect(map['source'], 'online');
            expect(map['online_url'], 'https://example.com/test.mp3');
        });

        test('displayDuration 格式化正确', () {
            final song = SongModel(
                id: '1',
                title: '测试',
                artist: '测试',
                duration: 269000, // 4分29秒 = 4:29
                source: SongSource.local,
            );

            expect(song.displayDuration, '4:29');
        });

        test('displayDuration 格式化 0 秒', () {
            final song = SongModel(
                id: '2',
                title: '测试',
                artist: '测试',
                duration: 30000, // 30秒 = 0:30
                source: SongSource.local,
            );

            expect(song.displayDuration, '0:30');
        });

        test('displayDuration 格式化长音频', () {
            final song = SongModel(
                id: '3',
                title: '测试',
                artist: '测试',
                duration: 3661000, // 61分1秒 = 61:01
                source: SongSource.local,
            );

            expect(song.displayDuration, '61:01');
        });

        test('copyWith 复制并修改部分字段', () {
            final original = SongModel(
                id: '1',
                title: '原曲',
                artist: '原歌手',
                duration: 200000,
                source: SongSource.local,
            );

            final modified = original.copyWith(
                title: '新曲',
                isFavorite: true,
            );

            // 原对象不变
            expect(original.title, '原曲');
            expect(original.isFavorite, false);

            // 新对象有修改
            expect(modified.title, '新曲');
            expect(modified.artist, '原歌手'); // 未修改的字段保留
            expect(modified.isFavorite, true);
        });

        test('fromMap 处理空值字段', () {
            final map = {
                'id': 'minimal',
                'title': '最简歌曲',
                'artist': null,
                'album': null,
                'duration': null,
                'source': 'local',
                'is_favorite': null,
                'play_count': null,
            };

            final song = SongModel.fromMap(map);

            expect(song.id, 'minimal');
            expect(song.title, '最简歌曲');
            expect(song.artist, ''); // null → 空字符串
            expect(song.album, null);
            expect(song.duration, 0); // null → 0
            expect(song.isFavorite, false); // null → false
            expect(song.playCount, 0); // null → 0
        });
    });
}
