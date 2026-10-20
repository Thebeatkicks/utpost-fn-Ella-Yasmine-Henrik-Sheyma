<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import type {
  ApiError,
  Photo,
  PhotoUploadRequest,
  PhotoUploadResponse,
  TourDetail,
} from '@utpost/shared'
import { get, post } from '../api'
import { elevationGain, formatKm } from '../lib/tours'

const route = useRoute()
const tour = ref<TourDetail | null>(null)
const error = ref<string | null>(null)

// M7: uppladdningen. Bara måtten och filnamnet lämnar browsern – bytes skickas inte än
// (Blob Storage är nästa steg). API:et lämnar över bildarbetet till funktionen process-image.
const photos = ref<Photo[]>([])
const upload = ref<PhotoUploadResponse | null>(null)
const uploadError = ref<string | null>(null)
const uploading = ref(false)

const loadPhotos = async () => {
  photos.value = await get<Photo[]>(`/photos/tour/${route.params.id}`)
}

onMounted(async () => {
  try {
    tour.value = await get<TourDetail>(`/tours/${route.params.id}`)
    await loadPhotos()
  } catch (err) {
    error.value = (err as Error).message
  }
})

const onFile = async (event: Event) => {
  const file = (event.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploading.value = true
  uploadError.value = null
  upload.value = null
  try {
    // createImageBitmap avkodar bilden i browsern – så får vi bredd och höjd utan att skicka den.
    const bitmap = await createImageBitmap(file)
    const body: PhotoUploadRequest = {
      tourId: Number(route.params.id),
      filename: file.name,
      width: bitmap.width,
      height: bitmap.height,
    }
    bitmap.close()
    const svar = await post<PhotoUploadResponse | ApiError>('/photos', body)
    if ('error' in svar) throw new Error(svar.error)
    upload.value = svar
    await loadPhotos()
  } catch (err) {
    uploadError.value = (err as Error).message
  } finally {
    uploading.value = false
  }
}

const SHOW_PHOTOS = 10
const latestPhotos = computed(() =>
  [...photos.value].sort((a, b) => b.id - a.id).slice(0, SHOW_PHOTOS),
)

const climb = computed(() => (tour.value ? elevationGain(tour.value.logs) : 0))

const time = (iso: string) => new Date(iso).toLocaleTimeString('sv-SE')
</script>

<template>
  <p v-if="error" role="alert">{{ error }}</p>
  <p v-else-if="!tour">Laddar…</p>
  <div v-else>
    <h1>{{ tour.title }}</h1>
    <p class="muted">
      {{ formatKm(tour.distance_m) }} · {{ tour.logs.length }} mätpunkter · {{ climb }} höjdmeter
    </p>
    <p v-if="tour.notes">{{ tour.notes }}</p>

    <section class="upload">
      <h2>Bilder</h2>
      <label>
        Ladda upp en bild
        <input type="file" accept="image/*" :disabled="uploading" @change="onFile" />
      </label>
      <p v-if="uploading" class="muted">Skalar om…</p>
      <p v-if="uploadError" role="alert">Uppladdningen misslyckades: {{ uploadError }}</p>
      <div v-if="upload" class="result" data-testid="upload-result">
        <p>
          <strong>{{ upload.filename }}</strong> · {{ upload.width }}×{{ upload.height }} ·
          bildarbetet {{ upload.processingMs }} ms · hela anropet {{ upload.apiMs }} ms
          <span v-if="upload.coldStart" class="cold">kallstart</span>
        </p>
        <ul>
          <li v-for="variant in upload.variants" :key="variant.size">
            {{ variant.size }} px · signatur {{ variant.signature }}
          </li>
        </ul>
        <p class="muted">instans {{ upload.instance }}</p>
      </div>
      <h3>Turens bilder ({{ photos.length }})</h3>
      <ul class="photos">
        <li v-for="photo in latestPhotos" :key="photo.id">
          {{ photo.filename }} · {{ photo.width }}×{{ photo.height }}
        </li>
      </ul>
      <p v-if="photos.length > SHOW_PHOTOS" class="muted">
        … och {{ photos.length - SHOW_PHOTOS }} äldre
      </p>
    </section>

    <h2>Mätpunkter</h2>
    <ol class="logs">
      <li v-for="log in tour.logs" :key="log.id">
        {{ time(log.recorded_at) }} · {{ log.elevation_m ?? '–' }} m ·
        {{ log.heart_rate ?? '–' }} slag/min
      </li>
    </ol>
  </div>
</template>

<style scoped>
.muted {
  color: #777;
  font-size: 14px;
}
.logs {
  font-size: 14px;
  color: #444;
  padding-left: 40px;
}
.upload {
  margin: 24px 0;
}
.result {
  border-left: 3px solid #2a7;
  padding-left: 12px;
}
.cold {
  background: #fde68a;
  border-radius: 4px;
  padding: 0 6px;
  font-size: 13px;
}
.photos {
  font-size: 14px;
  color: #444;
}
</style>
