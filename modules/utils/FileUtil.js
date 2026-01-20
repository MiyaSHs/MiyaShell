.pragma library

function _fileUrl(path) {
  // Ensure we have a file:// URL; QML's XHR works with file URLs.
  if (path.startsWith("file://")) return path;
  // Ensure absolute path.
  if (!path.startsWith("/")) {
    // best-effort: treat as relative
    return "file://" + Qt.resolvedUrl(path);
  }
  return "file://" + path;
}

function readText(path, callback) {
  var xhr = new XMLHttpRequest();
  xhr.onreadystatechange = function() {
    if (xhr.readyState === XMLHttpRequest.DONE) {
      if (xhr.status === 0 || (xhr.status >= 200 && xhr.status < 300)) {
        callback(null, xhr.responseText);
      } else {
        callback(new Error("HTTP status " + xhr.status), null);
      }
    }
  };
  xhr.open("GET", _fileUrl(path));
  xhr.send();
}

function readJson(path, callback) {
  readText(path, function(err, text) {
    if (err) return callback(err, null);
    try {
      var obj = JSON.parse(text);
      callback(null, obj);
    } catch (e) {
      callback(e, null);
    }
  });
}
