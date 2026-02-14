// PARCHE TEMPORAL PARA FUNCIONES DE API DE GITHUB
// Este archivo contiene las funciones que necesitas agregar al frontend

// Función para obtener ramas disponibles
const getBranches = async (instanceName) => {
  const token = localStorage.getItem('token');
  const API_BASE_URL = 'http://localhost:5000'; // Ajustar según tu configuración
  
  try {
    const response = await fetch(`${API_BASE_URL}/api/github/branches/${instanceName}`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return { data };
  } catch (error) {
    console.error('Error fetching branches:', error);
    throw error;
  }
};

// Función pull actualizada que soporta objetos
const pullUpdated = async (data) => {
  const token = localStorage.getItem('token');
  const API_BASE_URL = 'http://localhost:5000'; // Ajustar según tu configuración
  
  // Si data es string (instanceName), convertir a objeto para compatibilidad
  const requestData = typeof data === 'string' ? { instance_name: data } : data;
  
  try {
    const response = await fetch(`${API_BASE_URL}/api/github/pull`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestData)
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const responseData = await response.json();
    return { data: responseData };
  } catch (error) {
    console.error('Error doing pull:', error);
    throw error;
  }
};

// Exportar para uso temporal
window.githubApiFunctions = {
  getBranches,
  pull: pullUpdated
};

console.log('✅ Funciones de API de GitHub cargadas temporalmente');
console.log('Disponibles en: window.githubApiFunctions');

/*
INSTRUCCIONES PARA APLICAR PERMANENTEMENTE:

1. Abrir el archivo frontend/src/lib/api.js
2. Buscar el objeto 'github' 
3. Agregar estas funciones:

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
  
  // Actualizar función pull existente:
  pull: async (data) => {
    const token = localStorage.getItem('token');
    const requestData = typeof data === 'string' ? { instance_name: data } : data;
    return axios.post(`${API_BASE_URL}/api/github/pull`, requestData, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
  }
}
*/
