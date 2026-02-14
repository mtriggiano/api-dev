// PARCHE TEMPORAL PARA HABILITAR SELECTOR DE RAMAS
// Ejecuta este código en la consola del navegador (F12 → Console)

// Verificar si existe el objeto github en la API
if (typeof window.github === 'undefined' && typeof window.api !== 'undefined') {
  // Si existe window.api, usar esa estructura
  if (window.api.github) {
    console.log('📡 Patcheando API existente...');
    
    // Agregar función getBranches
    window.api.github.getBranches = async (instanceName) => {
      const token = localStorage.getItem('token');
      const API_BASE_URL = window.location.origin;
      
      try {
        const response = await fetch(`${API_BASE_URL}/api/github/branches/${instanceName}`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
          }
        });
        
        const data = await response.json();
        return { data };
      } catch (error) {
        console.error('Error fetching branches:', error);
        throw { response: { data: { error: error.message } } };
      }
    };
    
    // Guardar función pull original
    const originalPull = window.api.github.pull;
    
    // Actualizar función pull
    window.api.github.pull = async (data) => {
      const token = localStorage.getItem('token');
      const API_BASE_URL = window.location.origin;
      
      // Si data es string, convertir a objeto
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
        
        const responseData = await response.json();
        return { data: responseData };
      } catch (error) {
        console.error('Error doing pull:', error);
        throw { response: { data: { error: error.message } } };
      }
    };
    
    console.log('✅ API de GitHub patcheada exitosamente');
    console.log('✅ Función getBranches agregada');
    console.log('✅ Función pull actualizada');
    
  } else {
    console.error('❌ No se encontró window.api.github');
  }
} else {
  console.log('🔍 Buscando estructura de API...');
  console.log('window.github:', typeof window.github);
  console.log('window.api:', typeof window.api);
  
  // Crear estructura temporal si no existe
  if (!window.github) {
    window.github = {
      getBranches: async (instanceName) => {
        const token = localStorage.getItem('token');
        const API_BASE_URL = window.location.origin;
        
        try {
          const response = await fetch(`${API_BASE_URL}/api/github/branches/${instanceName}`, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json'
            }
          });
          
          const data = await response.json();
          return { data };
        } catch (error) {
          console.error('Error fetching branches:', error);
          throw { response: { data: { error: error.message } } };
        }
      },
      
      pull: async (data) => {
        const token = localStorage.getItem('token');
        const API_BASE_URL = window.location.origin;
        
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
          
          const responseData = await response.json();
          return { data: responseData };
        } catch (error) {
          console.error('Error doing pull:', error);
          throw { response: { data: { error: error.message } } };
        }
      }
    };
    
    console.log('✅ Objeto github temporal creado');
  }
}

// Forzar recarga del componente si está montado
if (window.React && window.React.version) {
  console.log('🔄 Intentando refrescar componentes React...');
  
  // Disparar evento personalizado para que el componente se recargue
  window.dispatchEvent(new CustomEvent('github-api-patched'));
}

console.log('🎉 Parche aplicado. Ahora deberías ver el selector de ramas funcionando.');
console.log('💡 Si no funciona inmediatamente, refresca la página (F5).');
