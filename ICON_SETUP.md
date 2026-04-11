# LANShare 图标配置说明

## 图标文件位置

### 源文件
- **原始Logo**: `assets/logo.png` - 应用内显示的Logo
- **源文件位置**: `/home/morgan/Downloads/LocalPulse-logo.png`

### 平台特定图标

#### Linux
- **路径**: `linux/runner/icons/icon.png`
- **尺寸**: 512x512 PNG
- **用途**: Linux桌面应用图标

#### Windows  
- **路径**: `windows/runner/resources/app_icon.ico`
- **尺寸**: 多尺寸ICO (16x16, 32x32, 48x48, 64x64, 128x128, 256x256)
- **用途**: Windows应用图标和任务栏图标

#### macOS
- **路径**: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- **尺寸**: 多种尺寸 (16x16 到 1024x1024)
- **用途**: macOS应用图标

## 图标在应用中的使用

### 1. 侧边栏Logo
在 [peer_panel.dart](file:///home/morgan/Documents/LANShare/lan_share/lib/presentation/screens/home/peer_panel.dart) 中，应用Logo显示在左侧面板顶部：

```dart
Image.asset(
  'assets/logo.png',
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Container(
      color: colorScheme.primary,
      child: Icon(Icons.wifi_tethering, color: colorScheme.onPrimary, size: 24),
    );
  },
)
```

### 2. 应用窗口图标
通过平台原生方式设置：
- **Linux**: 通过GTK窗口管理器自动识别
- **Windows**: 通过 `.ico` 文件
- **macOS**: 通过 `AppIcon.appiconset`

## 如何更新图标

### 方法1: 使用Python脚本（推荐）

```bash
cd /home/morgan/Documents/LANShare/lan_share
python3 << 'EOF'
from PIL import Image
import os

# 替换为你的新logo路径
src = '/path/to/new/logo.png'
img = Image.open(src)

# Windows ICO
sizes_ico = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
img.save('windows/runner/resources/app_icon.ico', format='ICO', sizes=sizes_ico)

# Linux
img.resize((512, 512), Image.LANCZOS).save('linux/runner/icons/icon.png')

# macOS
macos_dir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
for size in [16, 32, 64, 128, 256, 512, 1024]:
    img.resize((size, size), Image.LANCZOS).save(f'{macos_dir}/app_icon_{size}.png')

print("所有图标已更新！")
EOF
```

### 方法2: 手动替换

1. 替换源文件: `assets/logo.png`
2. 按上述路径手动生成各平台图标
3. 重新编译应用

## 编译和测试

### Linux
```bash
cd /home/morgan/Documents/LANShare/lan_share
flutter clean
flutter build linux
```

图标会显示在：
- 应用窗口标题栏
- 任务栏/启动器
- 文件管理器中的可执行文件

### Windows
```bash
flutter build windows
```

### macOS
```bash
flutter build macos
```

## 图标设计规范

### 建议尺寸
- **最小**: 1024x1024 px（源文件）
- **格式**: PNG（支持透明度）
- **背景**: 透明或纯色

### 设计要点
1. **简洁**: 图标在小尺寸下仍要清晰可辨
2. **对比度**: 确保在不同背景下都可见
3. **透明度**: 使用透明背景以适应不同主题
4. **一致性**: 与LANShare的品牌风格一致

## 故障排除

### 图标不显示？

1. **检查pubspec.yaml**
   ```yaml
   flutter:
     assets:
       - assets/logo.png
   ```

2. **清理并重新构建**
   ```bash
   flutter clean
   flutter pub get
   flutter build linux
   ```

3. **检查文件路径**
   ```bash
   ls -la assets/logo.png
   ls -la linux/runner/icons/icon.png
   ls -la windows/runner/resources/app_icon.ico
   ```

### 图标模糊？
- 确保源文件至少1024x1024
- 使用PNG格式而非JPG
- 检查是否正确生成了多尺寸图标

## 相关文件

- [pubspec.yaml](file:///home/morgan/Documents/LANShare/lan_share/pubspec.yaml) - 资源配置
- [peer_panel.dart](file:///home/morgan/Documents/LANShare/lan_share/lib/presentation/screens/home/peer_panel.dart) - UI显示
- [linux/runner/CMakeLists.txt](file:///home/morgan/Documents/LANShare/lan_share/linux/runner/CMakeLists.txt) - Linux构建配置

## 当前图标状态

✅ 已配置:
- `assets/logo.png` - 应用内Logo
- `linux/runner/icons/icon.png` - Linux图标
- `windows/runner/resources/app_icon.ico` - Windows图标
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/` - macOS图标

✅ 已测试:
- 代码分析通过 (`flutter analyze`)
- 无编译错误

## 下一步

运行应用查看新图标：
```bash
flutter run -d linux
```

图标应该显示在左侧面板顶部，带有应用名称和在线设备数量。
