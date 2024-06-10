

param name string
param location string
param lawClientId string
param lawClientSecret string


@description('Minimum number of replicas that will be deployed')
@minValue(0)
@maxValue(25)
param minReplicas int = 0

@description('Maximum number of replicas that will be deployed')
@minValue(0)
@maxValue(25)
param maxReplicas int = 1

param storageAccountName string
@secure()
param storageAccountKey string

param fileshareName string

resource env 'Microsoft.App/managedEnvironments@2023-05-01'= {
  name: 'containerapp-env-${name}'
  location: location
  properties: {   
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: lawClientId
        sharedKey: lawClientSecret
      }
    }
    workloadProfiles: [
      {
        name: 'BigCompute'
        workloadProfileType: 'D4'       
        maximumCount: 1
        minimumCount: 0
      }
      {
        name: 'Consumption'        
        workloadProfileType: 'Consumption'
      }
    ]    
  }
}

var storageName = 'acastorage'

resource envStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  name: 'containerapp-env-${name}/${storageName}'
  dependsOn: [
    env
  ]
  properties: {
    azureFile: {
      accessMode: 'ReadWrite'
      accountKey: storageAccountKey
      accountName: storageAccountName
      shareName: fileshareName
    }
  }
}


resource containerAppBackend 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'apiserver'
  dependsOn: [
    envStorage
  ]
  location: location  
  properties: {
    workloadProfileName: 'Consumption'
    managedEnvironmentId: env.id    
    configuration: {                  
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100            
          }
        ]
      }
    }
    template: {
      volumes: [
        {
          name: 'externalstorage'
          storageName: storageName
          storageType: 'AzureFile'          
        }
      ]      
      containers: [
        {          
          name: 'apiserver'
          image: 'dependencytrack/apiserver'                    
          resources: {
            cpu: json('4')
            memory: '8Gi'
          }
          volumeMounts: [
            {
              mountPath: '/data'
              volumeName: 'externalstorage'
            }
          ]
          env: [          
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }    
  }
}


resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'frontend'
  dependsOn: [
    envStorage
  ]
  location: location  
  properties: {
    managedEnvironmentId: env.id
    workloadProfileName: 'Consumption'
    configuration: {
      ingress: {      
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100            
          }
        ]
      }
    }
    template: {          
      containers: [
        {          
          name: 'frontend'
          image: 'dependencytrack/frontend'          
          resources: {
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'API_BASE_URL'
              value: 'https://apiserver.${env.properties.defaultDomain}'
            }
          ]          
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }    
  }
}
