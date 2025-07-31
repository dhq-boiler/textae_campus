module TokenChunk
  Token = Data.define(:token, :start_offset, :end_offset, :type)

  # Generate token chunks from JSON data using the specified window size
  def self.from(annotations, window_size: 20, strict_mode: true)
    # Raise ArgumentError if window_size is invalid
    raise ArgumentError, "window_size must be greater than 0" if window_size <= 0

    # Analyze the text
    tokens = SmartMultilingualTokenizer.new.analyze annotations["text"]

    # Generate chunks using the TokenChunkGenerator
    TokenChunkGenerator.new(annotations,
                            tokens,
                            window_size,
                            strict_mode: strict_mode)
                       .generate_chunks
  end
end
