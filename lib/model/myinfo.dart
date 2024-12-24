class MyInfo {
  late final int mid;
  late final String name;
  late final String face;
  late final String sign;

  MyInfo(this.mid, this.name, this.face, this.sign);

  MyInfo.fromJson(Map<String, dynamic> json) {
    mid = json['mid'];
    name = json['name'];
    face = json['face'];
    sign = json['sign'];
  }
}
