class ReleaseResult {
  ReleaseResult({
    required this.url,
    required this.assetsUrl,
    required this.uploadUrl,
    required this.htmlUrl,
    required this.id,
    required this.author,
    required this.nodeId,
    required this.tagName,
    required this.targetCommitish,
    required this.name,
    required this.draft,
    required this.prerelease,
    required this.createdAt,
    required this.publishedAt,
    required this.assets,
    required this.tarballUrl,
    required this.zipballUrl,
    required this.body,
  });
  late final String url;
  late final String assetsUrl;
  late final String uploadUrl;
  late final String htmlUrl;
  late final int id;
  late final Author author;
  late final String nodeId;
  late final String tagName;
  late final String targetCommitish;
  late final String name;
  late final bool draft;
  late final bool prerelease;
  late final String createdAt;
  late final String publishedAt;
  late final List<Assets> assets;
  late final String tarballUrl;
  late final String zipballUrl;
  late final String body;

  ReleaseResult.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    assetsUrl = json['assets_url'];
    uploadUrl = json['upload_url'];
    htmlUrl = json['html_url'];
    id = json['id'];
    author = Author.fromJson(json['author']);
    nodeId = json['node_id'];
    tagName = json['tag_name'];
    targetCommitish = json['target_commitish'];
    name = json['name'];
    draft = json['draft'];
    prerelease = json['prerelease'];
    createdAt = json['created_at'];
    publishedAt = json['published_at'];
    assets = List.from(json['assets']).map((e) => Assets.fromJson(e)).toList();
    tarballUrl = json['tarball_url'];
    zipballUrl = json['zipball_url'];
    body = json['body'];
  }
}

class Author {
  Author({
    required this.login,
    required this.id,
    required this.nodeId,
    required this.avatarUrl,
    required this.gravatarId,
    required this.url,
    required this.htmlUrl,
    required this.followersUrl,
    required this.followingUrl,
    required this.gistsUrl,
    required this.starredUrl,
    required this.subscriptionsUrl,
    required this.organizationsUrl,
    required this.reposUrl,
    required this.eventsUrl,
    required this.receivedEventsUrl,
    required this.type,
    required this.siteAdmin,
  });
  late final String login;
  late final int id;
  late final String nodeId;
  late final String avatarUrl;
  late final String gravatarId;
  late final String url;
  late final String htmlUrl;
  late final String followersUrl;
  late final String followingUrl;
  late final String gistsUrl;
  late final String starredUrl;
  late final String subscriptionsUrl;
  late final String organizationsUrl;
  late final String reposUrl;
  late final String eventsUrl;
  late final String receivedEventsUrl;
  late final String type;
  late final bool siteAdmin;

  Author.fromJson(Map<String, dynamic> json) {
    login = json['login'];
    id = json['id'];
    nodeId = json['node_id'];
    avatarUrl = json['avatar_url'];
    gravatarId = json['gravatar_id'];
    url = json['url'];
    htmlUrl = json['html_url'];
    followersUrl = json['followers_url'];
    followingUrl = json['following_url'];
    gistsUrl = json['gists_url'];
    starredUrl = json['starred_url'];
    subscriptionsUrl = json['subscriptions_url'];
    organizationsUrl = json['organizations_url'];
    reposUrl = json['repos_url'];
    eventsUrl = json['events_url'];
    receivedEventsUrl = json['received_events_url'];
    type = json['type'];
    siteAdmin = json['site_admin'];
  }
}

class Assets {
  Assets({
    required this.url,
    required this.id,
    required this.nodeId,
    required this.name,
    required this.uploader,
    required this.contentType,
    required this.state,
    required this.size,
    required this.downloadCount,
    required this.createdAt,
    required this.updatedAt,
    required this.browserDownloadUrl,
  });
  late final String url;
  late final int id;
  late final String nodeId;
  late final String name;
  late final Uploader uploader;
  late final String contentType;
  late final String state;
  late final int size;
  late final int downloadCount;
  late final String createdAt;
  late final String updatedAt;
  late final String browserDownloadUrl;

  Assets.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    id = json['id'];
    nodeId = json['node_id'];
    name = json['name'];
    uploader = Uploader.fromJson(json['uploader']);
    contentType = json['content_type'];
    state = json['state'];
    size = json['size'];
    downloadCount = json['download_count'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    browserDownloadUrl = json['browser_download_url'];
  }
}

class Uploader {
  Uploader({
    required this.login,
    required this.id,
    required this.nodeId,
    required this.avatarUrl,
    required this.gravatarId,
    required this.url,
    required this.htmlUrl,
    required this.followersUrl,
    required this.followingUrl,
    required this.gistsUrl,
    required this.starredUrl,
    required this.subscriptionsUrl,
    required this.organizationsUrl,
    required this.reposUrl,
    required this.eventsUrl,
    required this.receivedEventsUrl,
    required this.type,
    required this.siteAdmin,
  });
  late final String login;
  late final int id;
  late final String nodeId;
  late final String avatarUrl;
  late final String gravatarId;
  late final String url;
  late final String htmlUrl;
  late final String followersUrl;
  late final String followingUrl;
  late final String gistsUrl;
  late final String starredUrl;
  late final String subscriptionsUrl;
  late final String organizationsUrl;
  late final String reposUrl;
  late final String eventsUrl;
  late final String receivedEventsUrl;
  late final String type;
  late final bool siteAdmin;

  Uploader.fromJson(Map<String, dynamic> json) {
    login = json['login'];
    id = json['id'];
    nodeId = json['node_id'];
    avatarUrl = json['avatar_url'];
    gravatarId = json['gravatar_id'];
    url = json['url'];
    htmlUrl = json['html_url'];
    followersUrl = json['followers_url'];
    followingUrl = json['following_url'];
    gistsUrl = json['gists_url'];
    starredUrl = json['starred_url'];
    subscriptionsUrl = json['subscriptions_url'];
    organizationsUrl = json['organizations_url'];
    reposUrl = json['repos_url'];
    eventsUrl = json['events_url'];
    receivedEventsUrl = json['received_events_url'];
    type = json['type'];
    siteAdmin = json['site_admin'];
  }
}
