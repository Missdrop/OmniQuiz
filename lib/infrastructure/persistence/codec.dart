import '../../domain/models.dart';

Map<String, dynamic> chunkToJson(SourceChunk c) => {
  'id': c.id,
  'documentId': c.documentId,
  'documentName': c.documentName,
  'revision': c.revision,
  'location': c.location,
  'text': c.text,
};
SourceChunk chunkFromJson(Map<String, dynamic> j) => SourceChunk(
  id: j['id'],
  documentId: j['documentId'],
  documentName: j['documentName'],
  revision: j['revision'],
  location: j['location'],
  text: j['text'],
);
Map<String, dynamic> questionToJson(Question q) => {
  'id': q.id,
  'prompt': q.prompt,
  'options': q.options.map((o) => {'id': o.id, 'text': o.text}).toList(),
  'correctOptionId': q.correctOptionId,
  'explanation': q.explanation,
  'topic': q.topic,
  'source': chunkToJson(q.source),
  'quote': q.quote,
};
Question questionFromJson(
  Map<String, dynamic> j, {
  bool flagged = false,
  bool stale = false,
}) => Question(
  id: j['id'],
  prompt: j['prompt'],
  options: (j['options'] as List)
      .map((o) => AnswerOption(o['id'], o['text']))
      .toList(),
  correctOptionId: j['correctOptionId'],
  explanation: j['explanation'],
  topic: j['topic'],
  source: chunkFromJson(j['source']),
  quote: j['quote'],
  flagged: flagged,
  stale: stale,
);
Map<String, dynamic> profileToJson(ProviderProfile p) => {
  'baseUrl': p.baseUrl,
  'model': p.model,
  'jsonMode': p.jsonMode,
  'credentialRef': p.credentialRef,
  'language': p.language,
};
ProviderProfile profileFromJson(Map<String, dynamic> j) => ProviderProfile(
  baseUrl: j['baseUrl'],
  model: j['model'],
  jsonMode: j['jsonMode'] ?? false,
  credentialRef: j['credentialRef'] ?? '',
  language: j['language'] ?? '简体中文',
);
