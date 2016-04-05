MeCab = require 'mecab-async'
mecab = new MeCab();

# カタカタテキストをひらがなに変換する
katakanaToHiragana = (src) ->
	src.replace /[\u30a1-\u30f6]/g, (match) ->
		String.fromCharCode(match.charCodeAt(0) - 0x60)

# よみがなを取得する
# [TODO] 漢字だけで構成された未知語の場合はひらがなに変換できず、そのまま漢字を返してしまう
getYomi = (text, cb) ->
  mecab.parse text, (err, elements) ->
    return cb(err) if err

    # ele[8]: よみがな列、未知語の場合は ele[0] を使用する
    katakana = elements.map((ele) -> ele[8] || ele[0]).join('')
    cb(null, katakanaToHiragana(katakana))

class Siri
  # 単語の末尾を取得する
  @getTail: (word) ->
    word?.substr(-1)

  # 単語の語頭を取得する
  @getHead: (word) ->
    word?[0]

  # コンストラクタ
  constructor: (@robot) ->
    @_usedWords =
      'しりとり': null
      'りんご': null
      'ごま': null
      'ごまだれ': null
      'ごぼう': null
      'りくじょう': null
      'ごりら': null
      'らっぱ': null

    @_wordHistory = []

  # しりとりゲームを開始する
  start: ->
    @robot.respond /(.*)/, @_onReceiveAnswer.bind(@)

  # 人が答えた単語の末尾からつながる単語候補を見つける
  _findAnswers: (tail) ->
    Object.keys(@_usedWords).filter (word) =>
      word.startsWith(tail) && !@_usedWords[word]

  # 出現単語をクリアする
  _clearUsedWords: ->
    @_wordHistory = []

    for word of @_usedWords
      @_usedWords[word] = null

  # 使用済み単語としてマークする
  # マークされた単語は @_findAnswers() から除外される
  _markForUsed: (word) ->
    @_usedWords[word] = true
    @_wordHistory.push(word)
    word

  # word が使用済みかどうかを返す
  _isUsed: (word) ->
    @_usedWords[word] == true

  # 単語を返答する
  _answer: (res, word) ->
    res.reply @_markForUsed(word)

  # 勝つ
  _win: (res, message) ->
    res.reply message
    @_clearUsedWords()

  # 降参する
  _giveUp: (res, message) ->
    res.reply message
    @_clearUsedWords()

  # 指摘する
  _advise: (res, message) ->
    res.reply message

  # given がしりとり単語として使えるかどうかを返す
  _canConnect: (given) ->
    beforeWord = @_wordHistory[@_wordHistory.length - 1]
    # return true unless beforeWord

    !beforeWord || Siri.getTail(beforeWord) == Siri.getHead(given)

  # 末尾が「ん」かどうかを返す
  _isTailUn: (givenTail) ->
    givenTail == 'ん'

  _onReceiveAnswer: (res) ->
    given = res.match[1]

    getYomi given, (err, yomi) =>
      tail = Siri.getTail(yomi)
      @_markForUsed(yomi)

      return @_win(res, '「ん」がついたからあなたの負け!') if @_isTailUn(tail)
      return @_advise(res, '使えない単語です') unless @_canConnect(yomi)

      candidates = @_findAnswers(tail)

      if candidates.length > 0
        @_answer(res, candidates[0])
      else
        @_giveUp(res, '負けました (´・ω・`)')

module.exports = Siri
