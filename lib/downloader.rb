# frozen_string_literal: true

class Downloader
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def call
    return unless download?

    printf "\rDownloading #{filename} to #{path}\n"

    download

    printf "\rDownloaded #{filename} to #{path}\n"
  end

  def download
    length_formatted = format_to_human_readable(length)
    Faraday.get(url) do |req|
      req.options.on_data = lambda { |chunk, received_bytes|
        received_formatted = format_to_human_readable(received_bytes)

        printf "\rDownloading#{dots.next.ljust(5, ' ')} #{received_formatted}/#{length_formatted}"
        File.open(path, 'a:ASCII-8BIT') do |file|
          file.write(chunk)
        end
      }
    end
  end

  def unzip
    `gunzip -fk #{path}`
  end

  def update_dataset
    dataset.update(total: total_items)
  end

  def total_items
    @total_items ||= `wc -l #{dataset.path}`.split.first.to_i - 1
  end

  def format_to_human_readable(number)
    kb_formatted = (number.to_f / Numeric::KILOBYTE).round(2)
    formatted = kb_formatted > 1024 ? (number.to_f / Numeric::MEGABYTE).round(2) : kb_formatted

    "#{formatted.to_s.rjust(6, ' ')}#{kb_formatted == formatted ? 'KB' : 'MB'}"
  end

  def length
    @length ||= (head.headers['content-length'].to_f / Numeric::MEGABYTE).round(2)
  end

  def head
    @head ||= Faraday.head(url)
  end

  def download?
    return true unless File.exist?(path)

    false
  end

  def path
    dataset.download_path
  end

  def filename
    dataset.zip_filename
  end

  def url
    dataset.imdb_url
  end

  def dataset
    @dataset ||= Dataset.find_by(name: name)
  end

  def dots
    @dots ||= (1..4).map { |i| '.' * i }.cycle
  end
end
