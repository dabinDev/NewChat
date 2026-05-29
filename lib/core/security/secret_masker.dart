String maskSecret(String value) {
  if (value.isEmpty) {
    return '';
  }
  if (value.length < 12) {
    return '******';
  }
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}
