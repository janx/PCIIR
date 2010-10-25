require 'rubygems'
require 'feedzirra'

def get_word_counts(url)
  word_counts = Hash.new(0)

  feed = Feedzirra::Feed.fetch_and_parse(url)
  unless feed.is_a?(Feedzirra::Parser::RSS)
    puts "ERROR: cannot fetch feed #{url}"
    return [url, word_counts]
  end

  puts "counting words ..."
  for e in feed.entries
    words = get_words("#{e.title} #{e.summary}")
    words.each { |w| word_counts[w] += 1}
  end

  title = feed.title.strip.size > 0 ? feed.title : url
  [title, word_counts]
end

def get_words(html)
  html = html.gsub(/<[^>]+>/, '')
  html.split(/[^A-Z^a-z]+/).map(&:downcase)
end

def main
  # word appearence count. If a certain word appear in a feed, increase its count by 1
  # Note appear many times in a feed only increasing its count by 1
  apcount = Hash.new(0)

  word_counts = { }

  for url in File.readlines('feedlist.txt')
    url = url.chomp
    puts "fetching #{url} ..."
    title, feed_word_counts = get_word_counts(url)
    word_counts[title] = feed_word_counts

    feed_word_counts.each do |word, count|
      apcount[word] += 1 if count > 1
    end
  end

  # generate the word list we want use to grouping blogs
  # we exclude those common words (e.g. the) and those strange words (e.g Janstupid)
  # we should experiment the upper and lower bound to get best result
  word_list = []
  feed_count = File.readlines('feedlist.txt').size
  apcount.each do |word, count|
    percent = count.to_f/feed_count
    word_list << word if percent > 0.1 && percent < 0.5
  end

  # output to a file
  File.open('blogdata_jan.txt', 'w') do |f|
    f.puts "Blog\t#{word_list.join("\t")}"
    word_counts.each do |feed_title, feed_word_counts|
      f.puts "#{feed_title}\t#{feed_word_counts.values_at(*word_list).join("\t")}"
    end
  end
end

main
