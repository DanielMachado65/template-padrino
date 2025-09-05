# quake_parser.rb
require 'json'

class QuakeLogParser
  WORLD = '<world>'

  def initialize(file_path)
    @file_path = file_path
    reset_current_game!
    @games = []                   # lista de hashes por jogo
    @global_kills = Hash.new(0)   # ranking global
  end

  def parse
    File.foreach(@file_path) do |line|
      handle_game_boundaries(line)
      next unless @in_game

      capture_player(line)
      capture_kill(line)
    end

    # fecha o último jogo se terminou sem Shutdown/Exit
    flush_game! if @in_game

    output_json
  end

  private

  def reset_current_game!
    @in_game = false
    @players = Set.new
    @kills = Hash.new(0)          # kills por player dentro do jogo
    @kills_by_means = Hash.new(0) # causas de morte: MOD_*
    @total_kills = 0
  end

  def start_game!
    reset_current_game!
    @in_game = true
  end

  def end_game!
    flush_game!
    @in_game = false
  end

  def flush_game!
    # garante players ordenados e estrutura imutável
    game_hash = {
      total_kills: @total_kills,
      players: @players.to_a.sort,
      kills: @kills.sort.to_h,
      kills_by_means: @kills_by_means.sort.to_h
    }
    @games << game_hash
    reset_current_game!
  end

  def handle_game_boundaries(line)
    if line.include?('InitGame:')
      # se já estava dentro de uma partida, fecha a anterior
      flush_game! if @in_game
      start_game!
    elsif line.start_with?('  ') && (line.include?('ShutdownGame') || line.include?('Exit:'))
      end_game! if @in_game
    end
  end

  # Captura/atualiza players a partir de ClientUserinfoChanged
  def capture_player(line)
    return unless line.include?('ClientUserinfoChanged:')

    # padrão: ... n\PlayerName\ ...
    return unless line =~ /n\\([^\\]+)\\/

    name = ::Regexp.last_match(1).strip
    return if name.empty? || name == WORLD

    @players << name
    @kills[name] ||= 0
  end

  # Captura kills e causas (Kill:)
  def capture_kill(line)
    return unless line.include?('Kill:')

    # padrão: Kill: a b c: Killer killed Victim by MOD_SOMETHING
    return unless line =~ /Kill:\s+\d+\s+\d+\s+\d+:\s+(.+)\s+killed\s+(.+)\s+by\s+(MOD_[A-Z_]+)/

    killer = ::Regexp.last_match(1).strip
    victim = ::Regexp.last_match(2).strip
    cause = ::Regexp.last_match(3).strip

    @total_kills += 1
    @kills_by_means[cause] += 1

    # garante que vítimas e killers que aparecem sem ClientUserinfoChanged
    # ainda entrem em players (exceto <world>)
    if killer != WORLD
      @players << killer
      @kills[killer] ||= 0
      @kills[killer] += 1
      @global_kills[killer] += 1
    else
      # world kill: vítima perde 1
      unless victim == WORLD
        @players << victim
        @kills[victim] ||= 0
        @kills[victim] -= 1
        @global_kills[victim] -= 1
      end
    end
  end

  def output_json
    games_hash = {}
    @games.each_with_index do |g, idx|
      games_hash["game_#{idx + 1}"] = g
    end

    ranking = @global_kills
              .sort_by { |_, k| -k }
              .map { |player, kills| { player: player, kills: kills } }

    puts JSON.pretty_generate({
                                games: games_hash,
                                ranking: ranking
                              })
  end
end

# ---- Execução ----
# Ex.: ruby quake_parser.rb /caminho/para/qgames.log.txt
if ARGV.empty?
  warn "Uso: ruby #{__FILE__} /caminho/para/qgames.log.txt"
  exit 1
end

QuakeLogParser.new(ARGV[0]).parse
