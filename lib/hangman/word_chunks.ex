defmodule Hangman.Word.Chunks do
	defstruct key: Nil, raw_stream: Nil, chunk_count: Nil, word_count: Nil

	@moduledoc """
		Module to handle Hangman word list chunks for a given length
		Encapsulates raw stream consisting of binary chunks
	"""

	alias Hangman.{Word.Chunks}

  @chunk_words_size 500

	def new(length_key) when is_number(length_key) and length_key > 0 do
		%Chunks{key: length_key, raw_stream: [], chunk_count: 0, word_count: 0}
	end

  def new(length_key, %Stream{} = words, buf_size \\ @chunk_words_size)
  when is_number(length_key) and is_number(buf_size) and buf_size > 0 do
    
    # Take the stream, wrap it with indexes, and apply chunking

    fn_split_into_chunks = fn
      {_word, index} -> 
        _chunk_id = div(index, buf_size)
    end

		fn_normalize_chunks = fn 
			chunk -> 
				Enum.map_reduce(chunk, "", 
					fn {word, _index}, _acc -> {word, length_key} end)
		end

		fn_reduce_chunks = fn 
			{word_list, _} = _head, acc ->
	    	bin_chunk = :erlang.term_to_binary(word_list)
	    	chunk_size = Kernel.length(word_list)
	    	value = {bin_chunk, chunk_size}
	    	Chunks.add(acc, value)
    end

    chunks = words
    |> Stream.with_index
    |> Stream.chunk_by(fn_split_into_chunks)
    |> Stream.map(fn_normalize_chunks)
    |> Enum.reduce(Chunks.new(length_key), fn_reduce_chunks)

    chunks
  end

	@doc "Performs constant time lookup of number of words in stream"
	def get_count(%Chunks{raw_stream: raw_stream} = chunks, :words) do
		if is_nil(raw_stream), do: raise "need to create stream"
		
		chunks.word_count
	end

	@doc "Performs constant time lookup of number of chunks in stream"
	def get_count(%Chunks{raw_stream: raw_stream} = chunks, :chunks) do
		if is_nil(raw_stream), do: raise "need to create stream"
		
		chunks.chunk_count
	end

  def get_key(%Chunks{key: key} = _chunks), do: key

	@doc "Takes an existing chunk stream and a tuple value
		The tuple head is a binary chunk and the tail is the number of words"

	def add(%Chunks{raw_stream: raw_stream} = chunks, 
          {binary_chunk, word_count} = _v)
	when is_binary(binary_chunk) and is_number(word_count) 
  and word_count > 0 do

		if is_nil(raw_stream), do: raise "need to invoke new before using add"

		new_stream = Stream.concat(raw_stream, [binary_chunk])

		%Chunks{ chunks | raw_stream: new_stream,
			chunk_count: chunks.chunk_count + 1,
			word_count: chunks.word_count + word_count
		}
	end

  def get_words_lazy(%Chunks{raw_stream: raw_stream} = _stream) do
  	Stream.flat_map(raw_stream, &unpack(&1))
  end


  def transform_stream(stream, :sorted_dictionary, buffer_size) do

	  # lambda to split stream into chunks based on generated chunk id
		# Uses 1 + div() function to group consecutive, sorted words
		# Takes into account the current word-length-group index position and 
		# specified words-chunk buffer size, to determine chunk id

		#	A) Example of word stream before chunking
		#	{6, "mugful", 8509}
		#	{6, "muggar", 8510}
		#	{6, "mugged", 8511}
		#	{6, "muggee", 8512}

		fn_split_into_chunks = fn 
			{length, _word, length_group_index} -> 
				_chunk_id = length * ( 1 + div(length_group_index, buffer_size))
		end

		# lambda to normalize chunks
		# Flatten out / normalize chunks so that they contain 
    # only a list of words, and word length size

		# B) Example of chunk, before normalization
		#	[{6, "mugful", 8509}, {6, "muggar", 8510}, {6, "mugged", 8511},
		#	 {6, "muggee", ...}, {6, ...}, {...}, ...]

		fn_normalize_chunks = fn 
			chunk -> 
				Enum.map_reduce(chunk, "", 
					fn {length, word, _}, _acc -> {word, length} end)
		end

		#	C) Example of chunk after normalization
		#	{["mugful", "muggar", "mugged", "muggee", ...], 6}


    stream 
    |> Stream.chunk_by(fn_split_into_chunks)
    |> Stream.map(fn_normalize_chunks)

  end



  defp unpack(binary_chunk) when is_binary(binary_chunk) do
		_words_list = :erlang.binary_to_term(binary_chunk)
  end

end
