// Funciones adicionales para la API de GitHub
// Estas funciones deben agregarse al archivo frontend/src/lib/api.js

// Función para obtener las ramas disponibles de un repositorio
const getBranches = async (instanceName) => {
  const token = localStorage.getItem('token');
  return axios.get(`${API_BASE_URL}/api/github/branches/${instanceName}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
};

// Función actualizada para pull que soporta selección de rama
const pull = async (data) => {
  const token = localStorage.getItem('token');
  return axios.post(`${API_BASE_URL}/api/github/pull`, data, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
};

// Exportar las funciones para agregar al objeto github en api.js
export const githubApiFunctions = {
  getBranches,
  pull
};

/*
INSTRUCCIONES PARA INTEGRAR:

1. Abrir frontend/src/lib/api.js
2. Agregar la función getBranches al objeto github:

github: {
  // ... funciones existentes ...
  getBranches: async (instanceName) => {
    const token = localStorage.getItem('token');
    return axios.get(`${API_BASE_URL}/api/github/branches/${instanceName}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
  },
  
  // Actualizar la función pull existente para soportar data como objeto:
  pull: async (data) => {
    const token = localStorage.getItem('token');
    // Si data es string (instanceName), convertir a objeto para compatibilidad
    const requestData = typeof data === 'string' ? { instance_name: data } : data;
    return axios.post(`${API_BASE_URL}/api/github/pull`, requestData, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
  }
}

3. Guardar el archivo
*/
