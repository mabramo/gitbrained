class RepoItem {
  final String name;
  final String path;
  final String sha;
  final String type; // 'file' or 'dir'
  final String? downloadUrl;

  const RepoItem({
    required this.name,
    required this.path,
    required this.sha,
    required this.type,
    this.downloadUrl,
  });

  bool get isDir => type == 'dir';
  bool get isFile => type == 'file';
  bool get isMarkdown => isFile && name.endsWith('.md');

  factory RepoItem.fromJson(Map<String, dynamic> json) {
    return RepoItem(
      name: json['name'] as String,
      path: json['path'] as String,
      sha: json['sha'] as String,
      type: json['type'] as String,
      downloadUrl: json['download_url'] as String?,
    );
  }
}
