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
      @dictionaries = Dir.glob("#{@dic_dir}/*.yml")
    rescue => e
      error e
      Service.primary.post(message: "@#{Service.primary.user} D エラー発生: #{e}")
    end
  end


  def update_dictionary(message)
    Thread.new(message) { |m|
      matched = /@#{m.user.idname}\s辞書追加\s(?<type>.+)\s(?<word>.+)/.match(m)
      if matched.nil?
        m.post(message: 'D @ahiru3net 形式: @ahiru3net 辞書追加 辞書の種類 追加文')
      else
        Delayer::Deferred.fail("辞書 #{matched[:type]} は存在しません") unless @dictionaries.include?(matched[:type])

        # ファイルに書き出し
        File.open(File.join(@dic_dir, "#{matched[:type]}.yml")) do |f|
          f.puts("- \"#{matched[:word]}\"")
        end

        # TODO: git コマンドでコミット&プッシュを実行するようにする
      end
    }
  end


  on_appear do |ms|
    ms.each do |m|
      # 自分のみに反応する
      next if m.user[:id] != Service.primary.user_obj.id

      if m.to_s =~ /辞書追加/
        update_dictionary(m).trap { |e| error e }
      end
    end
  end

end
