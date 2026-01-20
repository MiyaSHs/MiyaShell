import QtQuick

QtObject {
  // 0 = Home
  // 1 = Library
  // 2 = Friends
  // 3 = Music
  // 4 = Downloads
  // 5 = Storage
  // 6 = Settings
  property int pageIndex: 0

  property bool overlayVisible: false

  // When true, the UI should attempt to capture input focus
  property bool uiFocused: true
}
