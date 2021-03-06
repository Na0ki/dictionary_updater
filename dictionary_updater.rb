# -*- coding: utf-8 -*-

Plugin.create(:dictionary_updater) do

  # before you run this plugin, you need to clone dictionary repository here
  # ./dictionary
  # ex. `$ git clone https://github.com/Na0ki/yakuna_dictionary dictionary`
  @dic_dir = File.join(__dir__, 'dictionary')

  def prepare
    @defined_time = Time.new.freeze

    begin
      raise('dictionary directory not found!') unless Dir.exists?(@dic_dir)

      # @see https://docs.ruby-lang.org/ja/latest/method/Dir/s/glob.html
      @dictionaries = Dir.glob("#{@dic_dir}/*.yml").map { |d| File.basename(d, '.*') }
    rescue => e
      error e
      Service.primary.post(message: "@#{Service.primary.user} D エラー発生: #{e}")
    end
  end


  def update_dictionary(message)
    prepare
    Thread.new(message) { |m|
      matched = /@#{m.user.idname}\s辞書追加\s(?<type>[\w\-]+?)\s(?<word>.+)/.match(m.to_s)
      if matched.nil?
        # 構文を間違えた際には自分にDする
        m.post(message: "D @#{m.user.idname} 形式: @#{m.user.idname} 辞書追加 辞書の種類 追加文")
      else
        Delayer::Deferred.fail("辞書 #{matched[:type]} は存在しません") unless @dictionaries.include?(matched[:type])

        # ファイルに書き出し
        File.open(File.join(@dic_dir, "#{matched[:type]}.yml"), 'a') do |file|
          file.puts("- \"#{matched[:word]}\"")
        end

        %x( cd #{@dic_dir} && git add "#{matched[:type]}.yml" && git commit -m "辞書更新" && git push origin master )
        result = $?.success?
        notice "辞書の更新に#{result ? '成功' : '失敗'}しました"
        if result
          m.post(:message => "辞書の追加が完了しました\n辞書更新\n %{time}" % {time: Time.now.to_s, result: result},
                 :replyto => m)
        end
      end
    }
  end


  on_appear do |ms|
    ms.each do |m|
      # メッセージ生成時刻が起動前またはリツイートならば次のループへ
      next if m[:created] < @defined_time or m.retweet?

      # 自分のみに反応する
      next if m.user[:id] != Service.primary.user_obj.id

      if m.to_s =~ /辞書追加/
        update_dictionary(m).trap { |e| error e }
      end
    end
  end

end
