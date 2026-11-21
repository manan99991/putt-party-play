#ifndef TENZY_STB_VORBIS_H
#define TENZY_STB_VORBIS_H

/// Decodes a whole Ogg Vorbis file held in memory to interleaved 16-bit samples.
/// Returns the number of samples per channel (negative on failure); *output must be freed with free().
int stb_vorbis_decode_memory(const unsigned char *mem, int len, int *channels, int *sample_rate, short **output);

#endif
